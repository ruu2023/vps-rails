# 旧 Rails 版 reservation(events テーブル)から新 reservation_events への
# データ移行。対応表: docs/plan/day2-reservation.md §4-2
#
# 移行対象は旧DBの特定1ユーザー分のみ(kaikei の移行と同じ方針)。email 経由で
# 行ごとにユーザーをマッピングすることはせず、投入先は常に環境変数
# RESERVATION_IMPORT_TARGET_EMAIL で指定した1ユーザー固定。メールアドレスを
# コードに直書きしない(git 管理のため)。CSV に user_email 列は含まない。
#
# デフォルトは既存データへの追加投入。RESERVATION_IMPORT_REPLACE=1 を指定すると
# インポート対象ユーザーの既存 reservation_events を先に全削除してから
# CSV を投入する(完全上書き)。削除は投入対象ユーザーの行のみが対象
# (他ユーザーの reservation_events には触れない)。
namespace :reservation do
  desc "旧 reservation データ(ignore/reservation_events_import.csv)を reservation_events へ移行する"
  task import_legacy_events: :environment do
    require "csv"

    csv_path = Pathname.new(ENV["RESERVATION_IMPORT_CSV_PATH"] || Rails.root.join("ignore/reservation_events_import.csv"))
    abort "[reservation:import_legacy_events] CSV が見つかりません: #{csv_path}" unless csv_path.exist?

    target_email = ENV["RESERVATION_IMPORT_TARGET_EMAIL"]
    abort "[reservation:import_legacy_events] RESERVATION_IMPORT_TARGET_EMAIL が未設定です" if target_email.blank?

    user = User.find_by(email: target_email)
    abort "[reservation:import_legacy_events] 投入先ユーザーが見つかりません: #{target_email}" unless user

    replace = ENV["RESERVATION_IMPORT_REPLACE"] == "1"

    if replace
      existing_count = user.reservation_events.count
      deleted_count = user.reservation_events.delete_all
      puts "[reservation:import_legacy_events] 完全上書きモード: #{user.email} の既存 reservation_events #{existing_count}件を削除しました(削除件数: #{deleted_count})"
    elsif Reservation::Event.exists? && ENV["RESERVATION_IMPORT_FORCE"] != "1"
      abort "[reservation:import_legacy_events] reservation_events に既存データがあります。二重投入防止のため中止しました。" \
            "再実行する場合は RESERVATION_IMPORT_FORCE=1(追加投入)または RESERVATION_IMPORT_REPLACE=1(完全上書き)を指定してください。"
    end

    utc = Time.find_zone("UTC")
    total = 0
    imported = 0
    skipped = []
    errored = []

    CSV.foreach(csv_path, headers: true) do |row|
      total += 1

      begin
        start_time = row["start_time"].presence && utc.parse(row["start_time"])
        end_time = row["end_time"].presence && utc.parse(row["end_time"])
      rescue ArgumentError => e
        skipped << { line: total, title: row["title"], reason: e.message }
        next
      end

      event = Reservation::Event.new(
        title: row["title"],
        start_time: start_time,
        end_time: end_time,
        has_end_time: row["has_end_time"] == "1",
        content: row["content"],
        user: user,
        skip_past_validation: true
      )

      if event.save
        imported += 1
      else
        errored << { line: total, title: row["title"], errors: event.errors.full_messages.join(", ") }
      end
    end

    puts "[reservation:import_legacy_events] モード: #{replace ? "完全上書き(既存削除→再投入)" : "追加投入"}"
    puts "[reservation:import_legacy_events] 投入先ユーザー: #{user.email} (id=#{user.id})"
    puts "[reservation:import_legacy_events] 対象件数: #{total}"
    puts "[reservation:import_legacy_events] 成功件数: #{imported}"
    puts "[reservation:import_legacy_events] スキップ件数(日時パース不能): #{skipped.size}"
    puts "[reservation:import_legacy_events] エラー件数(バリデーション失敗): #{errored.size}"

    if skipped.any?
      puts "[reservation:import_legacy_events] スキップ内訳:"
      skipped.each { |s| puts "  - line=#{s[:line]} title=#{s[:title]}: #{s[:reason]}" }
    end

    if errored.any?
      puts "[reservation:import_legacy_events] エラー内訳:"
      errored.each { |e| puts "  - line=#{e[:line]} title=#{e[:title]}: #{e[:errors]}" }
    end
  end
end
