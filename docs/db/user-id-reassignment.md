# user-id-reassignment.md — user_id 洗い替え手順書(恒久)

ある `User`(旧ユーザー)が所有しているデータを、別の `User`(新ユーザー)
の所有物として付け替えるための恒久手順書。`docs/db/er.md` の内容を前提に
書かれている(必ず先に読むこと)。スキーマが変わったら両方を更新する。

想定ユースケース: 最初のログインで意図しない Google アカウント(テスト
アカウント等)を使ってデータを作ってしまい、後から本来使うべき Google
アカウントに寄せたい、など。`<old_user_id>` / `<new_user_id>` はプレース
ホルダーであり、実施時に実際の ID に置き換える。

---

## 0. `docs/db/er.md` から導かれるチェックリスト(対象テーブル)

`docs/db/er.md` §2 のとおり、このスキーマには「親経由でしか user に
紐づかない」テーブルは存在しない。**5テーブル全てで `user_id` を直接
UPDATE する必要がある**。1つでも漏らすと、新ユーザーの画面上で
「取引はあるのに科目一覧に出てこない」のような不整合が起きる
(`docs/db/er.md` §2 の具体例を参照)。

- [ ] `kaikei_categories.user_id`(**論理削除済みの行も含む**。`unscoped` が必要)
- [ ] `kaikei_payment_methods.user_id`(**論理削除済みの行も含む**。`unscoped` が必要)
- [ ] `kaikei_budgets.user_id`
- [ ] `kaikei_transactions.user_id`
- [ ] `reservation_events.user_id`

`category_id` / `payment_method_id` そのもの(参照先レコードのID)は
変更しない。変更するのは各テーブルの `user_id` 列のみ
(参照先レコード自体の所有者を書き換えるだけで、参照関係は保たれる)。

---

## 1. 設計判断(実施前に確定させておくこと)

### 1-1. 新旧ユーザーを両方実在させたまま UPDATE するか、新ユーザーに寄せてから旧ユーザーを消すか

**結論: 選択の余地はなく、「両方実在させたまま子テーブルを UPDATE → その後
必要なら旧ユーザー行を消す」の順序しかとれない。**

理由は `docs/db/er.md` §4 の FK 制約による。5テーブル全ての `user_id`
FK は `on_delete` 指定なし(RESTRICT)なので、子テーブルがまだ旧
`user_id` を参照している状態で `users` 側の旧行を DELETE しようとすると
DB が外部キー制約違反でエラーを返す。つまり「先に旧ユーザーを消す」は
物理的に不可能で、必ず子テーブルの `user_id` を新ユーザーに向け直して
から(=旧ユーザーへの参照がゼロになってから)でないと旧ユーザー行を
消せない。

さらに `docs/db/er.md` §4 で述べたとおり、`User#destroy` の
`dependent: :destroy` は論理削除済みの科目・支払方法を拾わない
(`default_scope` の影響)。旧ユーザー行を最終的に削除するつもりなら、
論理削除済みの行も含めて `user_id` を漏れなく付け替えておく必要がある
(§0 のチェックリストで `unscoped` を明記しているのはこのため)。

推奨運用: **旧ユーザー行はこの手順の中では削除しない。** 全テーブルの
付け替えが完了し、新ユーザーで一定期間問題なく使えることを確認してから、
別作業として旧ユーザー行の削除要否を判断する(§5)。旧ユーザー行を
残しておくこと自体には実害がない(参照するデータが0件になるだけの
空アカウント行になる)。

### 1-2. `uid` / `provider`(Google OAuth の一意キー)の扱い

**結論: `users.provider` / `users.uid` は一切書き換えない。** これらは
Google が発行するアカウント識別子そのものであり、`User.from_google_omniauth`
が `find_or_create_by(provider:, uid:)` で突合するキーになっている。
この手順で書き換えるのは各テーブルの `user_id`(外部キー)だけで、
`users` テーブルの行自体(`provider`/`uid`/`email`)には触れない。

実施前に必ず確認すること:

- [ ] `<new_user_id>` の `users` 行の `email` / `provider` / `uid` が、
      「これから正としたい実際の Google アカウント」と一致していることを
      目視確認する(SELECT で確認。間違った `new_user_id` を指定すると、
      全データが意図しない Google アカウントに渡ってしまう)
- [ ] 旧ユーザーの Google アカウントを**今後も**使ってログインする
      可能性があるかを確認する。ある場合、旧ユーザー行を将来削除すると
      次回そのアカウントでログインした際に `find_or_create_by` が
      空の新規 `User` 行を作る(=旧アカウント自体は再利用可能な状態に
      戻る。データは新ユーザー側に残ったまま)。「もう二度とその
      Google アカウントを使わない」前提でない場合、旧ユーザー行を
      消すかどうかは特に慎重に判断する

---

## 2. 事前確認

- [ ] 新旧の `user_id` を確定させ、`email`/`provider`/`uid` を目視確認する
  ```ruby
  User.where(id: [ old_user_id, new_user_id ]).find_each do |u|
    puts [ u.id, u.email, u.provider, u.uid ].join(" | ")
  end
  ```
- [ ] 旧ユーザー・新ユーザーそれぞれの現在件数を記録する(付け替え後の
      件数照合に使う。論理削除済みも含めるため `unscoped` を使う)
  ```ruby
  [ old_user_id, new_user_id ].each do |uid|
    puts "user_id=#{uid}"
    puts "  kaikei_categories: #{Kaikei::Category.unscoped.where(user_id: uid).count}"
    puts "  kaikei_payment_methods: #{Kaikei::PaymentMethod.unscoped.where(user_id: uid).count}"
    puts "  kaikei_budgets: #{Kaikei::Budget.where(user_id: uid).count}"
    puts "  kaikei_transactions: #{Kaikei::Transaction.where(user_id: uid).count}"
    puts "  reservation_events: #{Reservation::Event.where(user_id: uid).count}"
  end
  ```
- [ ] 新ユーザー側に同名の科目・支払方法がすでに存在していないか
      目視で見比べる(名前の重複を防ぐバリデーションは存在しないため、
      付け替え後に同名科目が2件並ぶ状態になっても検出されない。
      問題なければそのまま進めてよいが、意図した状態か確認する)

## 3. バックアップ

方式の妥当性は `docs/db/backup-rollback-verification.md` で実機検証済み
(結論: `.backup` コマンド + ホスト側への `docker cp` 吸い出しが正しい)。

- [ ] `.backup` コマンドでコンテナ内の一時パスに一貫性のあるバックアップを作る
      (WAL に未チェックポイントの内容が残っていても `.backup` が正しく
      含めてくれるため、事前の手動 `wal_checkpoint` は不要)
  ```bash
  docker compose exec vps_rails sqlite3 storage/production.sqlite3 \
    ".backup '/tmp/production_backup.sqlite3'"
  ```
- [ ] `docker cp` でホスト側(リポジトリ外・ボリューム外の安全なパス)に
      吸い出す(**同じ名前付きボリューム内に置かない**。ボリューム自体が
      壊れる/消える障害に対してバックアップが無力になるため)
  ```bash
  docker cp vps_rails:/tmp/production_backup.sqlite3 \
    ~/vps-rails-backups/production.sqlite3.bak-$(date +%Y%m%d%H%M%S)
  docker compose exec vps_rails rm /tmp/production_backup.sqlite3
  ```
- [ ] バックアップファイルがホスト側に作成されたことを確認する

## 4. 実行(1トランザクションで5テーブルまとめて UPDATE)

`update_all` はバリデーション・コールバックを通らないため、`user_id`
という外部キー1列を書き換えるだけのこの用途では問題ない(ドメイン側の
値は一切変更しないため)。**論理削除済みの科目・支払方法を漏らさない
ために `unscoped` を使う**のが最重要ポイント(§0 参照)。

- [ ] `bin/rails runner` で以下を1トランザクションとして実行する
  ```ruby
  ActiveRecord::Base.transaction do
    old_id = old_user_id
    new_id = new_user_id

    Kaikei::Category.unscoped.where(user_id: old_id).update_all(user_id: new_id)
    Kaikei::PaymentMethod.unscoped.where(user_id: old_id).update_all(user_id: new_id)
    Kaikei::Budget.where(user_id: old_id).update_all(user_id: new_id)
    Kaikei::Transaction.where(user_id: old_id).update_all(user_id: new_id)
    Reservation::Event.where(user_id: old_id).update_all(user_id: new_id)
  end
  ```
  `kaikei_budgets` の一意インデックス `(user_id, category_id, year, month)`
  に注意: 新ユーザー側に同じ `category_id`/`year`/`month` の予算が
  すでに存在すると、この UPDATE がユニーク制約違反で失敗する
  (トランザクション内なので失敗時は全体がロールバックされる。§2 の
  事前確認で新ユーザー側の予算も見ておくとよい)

## 5. 検証

- [ ] 旧 `user_id` の残存件数が全テーブルで 0 であることを確認する
      (§2 で使ったスクリプトを再実行し、`old_user_id` 側が全て 0 になっているか)
- [ ] 新 `user_id` 側の件数が「§2 で記録した新ユーザーの元の件数 + 旧ユーザーの
      件数」と一致することを確認する
- [ ] 非DB制約(`docs/db/er.md` §5)が壊れていないか確認する
      (取引・予算が参照している科目・支払方法の `user_id` が、
      取引・予算自身の `user_id` と一致しているか)
  ```ruby
  mismatched_tx = Kaikei::Transaction.where(user_id: new_user_id)
    .joins("INNER JOIN kaikei_categories ON kaikei_categories.id = kaikei_transactions.category_id")
    .where.not("kaikei_categories.user_id = kaikei_transactions.user_id")
  puts "category user_id 不一致の取引: #{mismatched_tx.count}"

  mismatched_budget = Kaikei::Budget.where(user_id: new_user_id)
    .joins("INNER JOIN kaikei_categories ON kaikei_categories.id = kaikei_budgets.category_id")
    .where.not("kaikei_categories.user_id = kaikei_budgets.user_id")
  puts "category user_id 不一致の予算: #{mismatched_budget.count}"
  ```
  (§4 で5テーブル全てを同じ `new_user_id` に揃えていれば、これらは
  常に 0 件になるはず。0 件でなければ §0 のテーブルのどれかを
  更新し忘れている)
- [ ] ブラウザで新ユーザーとしてログインし、kaikei(取引一覧・科目設定・
      予算・分析)と reservation(カレンダー)の各画面にデータが表示され、
      科目一覧・支払方法一覧にも過不足なく出ることを確認する

## 6. 旧ユーザー行の扱い

§1-1 の推奨運用のとおり、この手順の範囲では旧ユーザー行を削除しない。
削除するかどうかは、新ユーザー側での運用が安定してから別途判断する。
削除する場合は以下を満たしていることを確認してから `User.find(old_id).destroy`
または直接 `DELETE FROM users WHERE id = <old_user_id>` を実行する。

- [ ] §5 の検証で旧 `user_id` の残存件数が全テーブルで 0 であることを
      再確認済み(論理削除済みの科目・支払方法も含む)
- [ ] §1-2 で確認した「旧 Google アカウントを今後使う可能性」を踏まえ、
      削除して問題ないと判断済み

## 7. ロールバック(問題があった場合)

方式の妥当性は `docs/db/backup-rollback-verification.md` で実機検証済み
(結論: `docker compose exec` は停止中コンテナに効かない/停止後は
`docker compose run --rm` を使う、書き戻し前に `-wal`/`-shm` を消さないと
ロールバックしたはずの内容が復活する、の2点)。

- [ ] コンテナを停止する: `docker compose stop vps_rails`
- [ ] 停止中コンテナには `docker compose exec` が使えないため、
      同じボリュームに繋がる使い捨てコンテナ(`docker compose run --rm`)
      で、**残っている `-wal`/`-shm` を先に削除してから**バックアップを
      書き戻す(順序が逆だと、書き戻し後に古い `-wal` が再生されて
      ロールバックしたはずの変更が復活する)
  ```bash
  docker compose run --rm \
    -v ~/vps-rails-backups:/backup \
    vps_rails sh -c "
      rm -f storage/production.sqlite3-wal storage/production.sqlite3-shm &&
      cp /backup/production.sqlite3.bak-<timestamp> storage/production.sqlite3
    "
  ```
- [ ] コンテナを再起動し、§2 で記録した件数に戻っていることを確認する:
      `docker compose start vps_rails`
