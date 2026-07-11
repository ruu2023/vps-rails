# 旧 Laravel 版 kaikei DB(MySQL ダンプ)から新 Rails 版へのデータ移行。
# 対応表: docs/spec/kaikei/migration-map.md
namespace :kaikei do
  desc "旧 Laravel 版 kaikei ダンプ(ignore/kaikei_dump_20260711.sql)を新スキーマへ移行する"
  task migrate_legacy_dump: :environment do
    require "time"

    dump_path = Pathname.new(ENV["KAIKEI_DUMP_PATH"] || Rails.root.join("ignore/kaikei_dump_20260711.sql"))
    abort "[kaikei:migrate_legacy_dump] ダンプファイルが見つかりません: #{dump_path}" unless dump_path.exist?

    target_email = ENV["KAIKEI_MIGRATION_EMAIL"] || "kokihiru2038@gmail.com"
    user = User.find_by(email: target_email)
    abort "[kaikei:migrate_legacy_dump] 対象ユーザーが見つかりません: #{target_email}" unless user

    sql = dump_path.read

    # --- MySQL dump の INSERT INTO `table` VALUES (...),(...); を素朴にパースする ---
    parse_values = lambda do |str|
      tuples = []
      i = 0
      len = str.length
      while i < len
        i += 1 until i >= len || str[i] == "("
        break if i >= len

        j = i + 1
        fields = []
        current = +""
        quoted = false
        in_string = false

        while j < len
          c = str[j]
          if in_string
            case c
            when "\\"
              current << str[j + 1]
              j += 2
              next
            when "'"
              if str[j + 1] == "'"
                current << "'"
                j += 2
                next
              else
                in_string = false
                j += 1
                next
              end
            else
              current << c
              j += 1
              next
            end
          else
            case c
            when "'"
              in_string = true
              quoted = true
              j += 1
            when ","
              fields << (quoted ? current : (current == "NULL" ? nil : current))
              current = +""
              quoted = false
              j += 1
            when ")"
              fields << (quoted ? current : (current == "NULL" ? nil : current))
              tuples << fields
              j += 1
              break
            else
              current << c
              j += 1
            end
          end
        end
        i = j
      end
      tuples
    end

    extract_table = lambda do |table|
      match = sql.match(/INSERT INTO `#{table}` VALUES\s+(.*?);\n/m)
      match ? parse_values.call(match[1]) : []
    end

    raw_categories = extract_table.call("categories")
    raw_payment_methods = extract_table.call("payment_methods")
    raw_transactions = extract_table.call("transactions")

    # budgets / clients はダンプ内のデータが 0 件のため移行対象外(migration-map.md 参照)
    # users テーブルも移行しない(認証方式が Google OAuth に変わるため)

    puts "[kaikei:migrate_legacy_dump] ダンプから読み取った件数: categories=#{raw_categories.size}, payment_methods=#{raw_payment_methods.size}, transactions=#{raw_transactions.size}"

    # --- 本番ユーザー(旧DB user_id)の transactions だけに絞り込む ---
    # categories は絞り込まず全件投入する。
    legacy_user_id = (ENV["KAIKEI_LEGACY_USER_ID"] || "5").to_i

    raw_transactions = raw_transactions.select { |row| row[6].to_i == legacy_user_id }

    # 旧DB payment_methods.id=5(「現金/expense」, 実体は user_id=2 のマスタ)は、
    # 取引入力画面のバグにより user_id=5 の取引から誤って参照されていた。
    # 本来 user_id=5 が使うべきなのは同内容の id=1(「現金/expense」)のため、
    # 投入時に payment_method_id=5 を 1 に読み替えて正す。
    remapped_payment_method_count = 0
    raw_transactions = raw_transactions.map do |row|
      next row unless row[7]&.to_i == 5

      remapped_payment_method_count += 1
      row = row.dup
      row[7] = "1"
      row
    end

    # payment_methods は、読み替え後の transactions が実際に参照している
    # payment_method_id の集合のみ投入する(id=5 は参照されなくなるため投入しない)。
    referenced_payment_method_ids = raw_transactions.filter_map { |row| row[7]&.to_i }.uniq
    raw_payment_methods = raw_payment_methods.select { |row| referenced_payment_method_ids.include?(row[0].to_i) }

    puts "[kaikei:migrate_legacy_dump] 旧DB user_id=#{legacy_user_id} に絞り込み後の件数: categories=#{raw_categories.size}, payment_methods=#{raw_payment_methods.size}, transactions=#{raw_transactions.size}"
    puts "[kaikei:migrate_legacy_dump] payment_method_id を 5→1 に読み替えた取引件数: #{remapped_payment_method_count}"

    # --- 新スキーマの CHECK 制約 + アプリのビジネスルールを事前検証する ---
    errors = []

    category_default_types = {} # old category_id => default_type
    raw_categories.each do |row|
      id, _name, _icon, default_type, _sort_order, _created_at, _deleted_at = row
      unless Kaikei::Category::TYPES.include?(default_type)
        errors << "categories id=#{id}: default_type が不正です(#{default_type.inspect})"
      end
      category_default_types[id.to_i] = default_type
    end

    payment_method_ids = raw_payment_methods.map { |row| row[0].to_i }
    raw_payment_methods.each do |row|
      id, _name, type, _user_id = row
      unless Kaikei::PaymentMethod::TYPES.include?(type)
        errors << "payment_methods id=#{id}: type が不正です(#{type.inspect})"
      end
    end

    category_ids = category_default_types.keys
    raw_transactions.each do |row|
      id, _date, amount, type, _memo, category_id, _user_id, payment_method_id, _client_id, _created_at, _updated_at, _client_name = row

      unless Kaikei::Transaction::TYPES.include?(type)
        errors << "transactions id=#{id}: type が不正です(#{type.inspect})"
      end

      if amount.to_i < 0
        errors << "transactions id=#{id}: amount が負数です(#{amount})"
      end

      unless category_ids.include?(category_id.to_i)
        errors << "transactions id=#{id}: category_id=#{category_id} に対応する categories 行がダンプ内にありません"
      end

      if payment_method_id && !payment_method_ids.include?(payment_method_id.to_i)
        errors << "transactions id=#{id}: payment_method_id=#{payment_method_id} に対応する payment_methods 行がダンプ内にありません"
      end

      default_type = category_default_types[category_id.to_i]
      if default_type && type && default_type != type
        errors << "transactions id=#{id}: type(#{type}) が科目 category_id=#{category_id} の default_type(#{default_type})と一致しません"
      end
    end

    if errors.any?
      puts "[kaikei:migrate_legacy_dump] 検証エラーのため投入を中止します(#{errors.size}件):"
      errors.each { |e| puts "  - #{e}" }
      abort "[kaikei:migrate_legacy_dump] 投入は行われていません"
    end

    puts "[kaikei:migrate_legacy_dump] 検証OK。投入を開始します(対象ユーザー: #{user.email}, id=#{user.id})"

    before_counts = {
      categories: Kaikei::Category.unscoped.where(user_id: user.id).count,
      payment_methods: Kaikei::PaymentMethod.where(user_id: user.id).count,
      transactions: Kaikei::Transaction.where(user_id: user.id).count
    }
    puts "[kaikei:migrate_legacy_dump] 投入前件数: #{before_counts}"

    run_at = Time.zone.now

    ActiveRecord::Base.transaction do
      # 冪等性のため、対象ユーザーの既存データを一度削除してから再投入する。
      # 外部キー制約があるため子(transactions)から先に消す。
      Kaikei::Transaction.where(user_id: user.id).delete_all
      Kaikei::Category.unscoped.where(user_id: user.id).delete_all
      Kaikei::PaymentMethod.where(user_id: user.id).delete_all

      category_rows = raw_categories.map do |row|
        id, name, icon, default_type, sort_order, created_at, deleted_at = row
        created_at_t = Time.zone.parse(created_at)
        {
          id: id.to_i,
          user_id: user.id,
          name: name,
          icon: icon,
          default_type: default_type,
          sort_order: sort_order.to_i,
          created_at: created_at_t,
          updated_at: created_at_t, # 旧テーブルに updated_at が無いため created_at を流用
          deleted_at: deleted_at ? Time.zone.parse(deleted_at) : nil
        }
      end
      Kaikei::Category.insert_all!(category_rows) if category_rows.any?

      payment_method_rows = raw_payment_methods.map do |row|
        id, name, type, _user_id = row
        {
          id: id.to_i,
          user_id: user.id,
          name: name,
          type: type,
          created_at: run_at, # 旧テーブルに created_at/updated_at が無いため実行日時で補完
          updated_at: run_at
        }
      end
      Kaikei::PaymentMethod.insert_all!(payment_method_rows) if payment_method_rows.any?

      transaction_rows = raw_transactions.map do |row|
        id, date, amount, type, memo, category_id, _user_id, payment_method_id, _client_id, created_at, updated_at, client_name = row
        {
          id: id.to_i,
          user_id: user.id,
          date: Date.parse(date),
          amount: amount.to_i,
          type: type,
          memo: memo,
          category_id: category_id.to_i,
          payment_method_id: payment_method_id&.to_i, # client_id は使われていない列のため無視(migration-map.md 参照)
          client_name: client_name,
          created_at: Time.zone.parse(created_at),
          updated_at: Time.zone.parse(updated_at)
        }
      end
      Kaikei::Transaction.insert_all!(transaction_rows) if transaction_rows.any?
    end

    after_counts = {
      categories: Kaikei::Category.unscoped.where(user_id: user.id).count,
      payment_methods: Kaikei::PaymentMethod.where(user_id: user.id).count,
      transactions: Kaikei::Transaction.where(user_id: user.id).count
    }
    puts "[kaikei:migrate_legacy_dump] 投入後件数: #{after_counts}"
    puts "[kaikei:migrate_legacy_dump] 完了しました"
  end
end
