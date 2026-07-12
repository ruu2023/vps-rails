# day2-reservation.md — reservation 機能 移植実装計画(Day2)

このドキュメントは reservation(予約カレンダー)機能の移植実装計画であり、
作業ログ兼チェックリストとして扱う。実装が進むごとにチェックボックスを
更新すること。

ベース資料:
- `docs/spec/reservation/`(overview / models / routes / dependencies /
  business_logic / known_issues)
- 先に提示した移植実行計画(命名対応表・スタック書き換え方針・骨組み手順・
  マイグレーション設計・実装順序)
- 本ドキュメント作成時点で確定した確認事項 a〜h(下記 §0)

対象外: kaikei の名前空間・コードには一切触れない。

---

## §0. 確定事項(確認事項 a〜h への回答と根拠)

| # | 論点 | 決定 | 根拠 |
|---|---|---|---|
| a | カレンダー UI | 自前 Hotwire ネイティブ化は**不採用**。FullCalendar を `bin/importmap pin` で取り込む(CDN の `<script>` は使わない = Chart.js と同じ扱い)。イベントデータは `events.json` のような JSON API を作らず、サーバーで描画済みのデータを DOM(`<script type="application/json">` 等)に埋め込み FullCalendar に JS 配列として渡す。CRUD は Turbo Streams。 | 移行元が複数日にまたがる予定のバー描画のために JS 化した経緯があり、自前実装すると同じ課題(複数日スパン描画)が再燃するため。CDN 直読み・生 JSON API 常設は vps-rails 規約(「fetch/axios + JSON API は使わない」)違反になるため、importmap + DOM 埋め込みで規約と両立させる |
| b | タイムゾーン | `config/application.rb` に `config.time_zone = "Tokyo"` のみ追加。`config.active_record.default_timezone` は変更せず `:utc` のまま維持 | kaikei の既存 datetime データの解釈(DB 保存値の TZ 解釈)を壊さないため。アプリ全体の設定変更だが、影響は「表示・入力時のローカル時刻扱い」のみで DB 保存形式は変えない |
| c | root 導線 | 現状維持。`root` は `/kaikei/dashboard` のまま、`sessions#create` の固定リダイレクトも変更しない。reservation は `/reservation/events` に直接アクセスする形にとどめる | 機能選択ページは範囲外。既存の導線を壊さないことを優先し、後続フェーズで検討 |
| d | 開発環境自動ログイン | 作らない | 認証は Google OAuth 一本化(vps-rails 共通方針)。known_issues #10 のリスクをそもそも作らない |
| e | 既存データ移行 | 本番データあり。移行手順を実施する(§4-2 参照) | 移行元に実データが存在するため、新規スタートにはできない |
| f | リアルタイム更新 | 今回のスコープに**含める**。Turbo Streams + Solid Cable で同一ユーザーの他タブ同期まで実装する | 移行元に元々あった機能であり必須要件 |
| g | PWA | 今回はスコープ外。ただし破棄はしない。manifest / service worker には一切触れない | 優先度が低く、Hotwire 化・データ移行・リアルタイム更新を優先するため。TODO として本ドキュメント末尾(§6)に残す |
| h | `holiday_jp` gem | Gemfile に追加する | 祝日色分け(土曜=青、日曜・祝日=赤)を実現するため。reservation 機能由来の追加 gem |

---

## §1. 命名対応表

| 移行元 | vps-rails での対応 | 備考 |
|---|---|---|
| `users` テーブル / `User` モデル | 新規に作らない。既存の共有 `users` テーブル・`User` モデルをそのまま使う | 既存 `User` に `name/email/avatar_url/provider/uid` が既に揃っている(移行元の `image` は `avatar_url` 相当) |
| `User#events`(has_many) | `User` に `has_many :reservation_events, class_name: "Reservation::Event", dependent: :destroy` を追記 | kaikei の `has_many :kaikei_transactions, ...` と同じパターン。追記のみ、既存行は変更しない |
| `Event` モデル / `events` テーブル | `Reservation::Event` / `reservation_events`(`self.table_name = "reservation_events"`) | 名前衝突なし |
| `EventsController` | `Reservation::EventsController < Reservation::BaseController` | |
| `SessionsController` | 触らない。既存の共通 `SessionsController`(`/login`, `/logout`, `/auth/google_oauth2/callback`)をそのまま使う | reservation 独自の認証コードは作らない(確定事項 d も参照) |
| `resources :events`(トップレベル) | `namespace :reservation do resources :events, except: [:show] end` | `show` 未実装 + 認可漏れの known issue #4 を踏襲せず最初から除外 |
| `sessions/new`, `sessions/create`, `sessions/destroy` の不要 GET ルート | 移植しない | vps-rails 側にはそもそも存在しない(known_issues #3 は発生しない) |
| FullCalendar(CDN 読み込み) | `bin/importmap pin` で取り込む(確定事項 a) | Chart.js と同じ扱い |
| `events.json` API | 作らない(確定事項 a) | サーバー描画データを DOM 埋め込みで渡す方式に置き換え |
| `holiday_jp` gem | Gemfile に追加(確定事項 h) | 名前空間的な衝突なし |
| `time_sync_controller.js` | `app/javascript/controllers/reservation/time_sync_controller.js`(`reservation--time-sync`) | kaikei の Stimulus 配置規約と同型 |
| Turbo Streams 配信チャンネル名(`events_user_#{user_id}`) | `reservation_events_user_#{user_id}` | reservation 名前空間であることを明示 |
| 開発環境自動ログイン | 作らない(確定事項 d) | |
| `app/mailers/application_mailer.rb` の予約系メール | 移植しない | 未実装機能、スコープ外 |
| PWA(manifest / service worker) | 今回は触らない(確定事項 g) | 後続フェーズ TODO(§6) |

---

## §2. スタック書き換え方針

| 項目 | 方針 |
|---|---|
| Propshaft / SQLite / Hotwire / Tailwind / Solid Queue / Solid Cache / Solid Cable / Devise なし / Kamal | vps-rails 側と同一スタックなのでそのまま。書き換え不要 |
| 認証(cookie 独自実装 → セッション) | reservation は独自実装を持たず、共通 `Authentication` concern(`session[:user_id]`)にそのまま乗る |
| User モデル統合 | 独自 User を作らず、共有 User に `has_many` を1行追加するのみ |
| カレンダーライブラリ(FullCalendar CDN) | **確定(a)**: importmap で pin。イベントデータは DOM 埋め込みで渡し、`events.json` は作らない。CRUD は Turbo Streams |
| タイムゾーン | **確定(b)**: `config.time_zone = "Tokyo"` を `config/application.rb` に追加。`config.active_record.default_timezone` は変更しない(`:utc` のまま) |
| `holiday_jp` gem | **確定(h)**: Gemfile に追加するだけ |
| jbuilder / image_processing | vps-rails に既に共通 gem として存在。reservation 側で個別の追加・削除判断は不要(現状維持) |
| CSP 無効化(known_issues #9) | vps-rails 側も現状 CSP は無効化されたまま(pre-existing)。reservation が CDN 依存を作らないため新たな緊急性は生じない。CSP 全体の有効化は本タスクのスコープ外 |
| リアルタイム更新 | **確定(f)**: Turbo Streams + Solid Cable で実装する(vps-rails 標準スタックそのまま、追加インフラ不要) |
| PWA | **確定(g)**: 今回は着手しない。破棄はせず後続フェーズ TODO として残す |

---

## §3. 骨組み作成手順(kaikei と同じ型)

- [ ] `Gemfile` に `gem "holiday_jp"` を追加し `bundle install`
- [ ] `config/routes.rb` に `namespace :reservation do resources :events, except: [:show] end` を追加(既存 `kaikei` ブロックは変更しない)
- [ ] `app/models/reservation/` ディレクトリを作成
- [ ] `app/controllers/reservation/base_controller.rb`(`layout "reservation"`)を作成 — `Kaikei::BaseController` と同型
- [ ] `app/views/layouts/reservation.html.erb` を作成 — `kaikei.html.erb` と同型(`render template: "layouts/application"` で内側から包む)
- [ ] `app/views/reservation/shared/_header.html.erb` を作成
- [ ] `app/javascript/controllers/reservation/` ディレクトリを作成
- [ ] `app/models/user.rb` に `has_many :reservation_events, class_name: "Reservation::Event", dependent: :destroy` を1行追記(既存 kaikei 関連行は変更しない)
- [ ] `test/controllers/reservation/`, `test/models/reservation/` ディレクトリ、`test/fixtures/reservation_events.yml` を作成
- [ ] `config/application.rb` に `config.time_zone = "Tokyo"` を追加(確定事項 b。kaikei にも影響する全体変更である旨をコミットメッセージ等に明記する)
- [ ] `bin/importmap pin` で FullCalendar 関連パッケージ(core / daygrid / interaction 等、必要なプラグインは実装時に importmap pin で解決)を取り込む

---

## §4. マイグレーション設計

### §4-1. スキーマ

新規作成は **`reservation_events` テーブルのみ**(`users` は既存流用のため新規テーブル不要)。

```ruby
create_table "reservation_events" do |t|
  t.string   "title"
  t.datetime "start_time"
  t.datetime "end_time"
  t.boolean  "has_end_time", null: false, default: false
  t.text     "content"
  t.integer  "user_id", null: false
  t.timestamps
end
add_index "reservation_events", "user_id"
add_foreign_key "reservation_events", "users"
```

- [ ] マイグレーションファイル作成
- [ ] `rails db:migrate`

### §4-2. 既存データ移行(確定事項 e)

移行元に本番データがあるため実施する。**最重要ポイントは user_id の付け替え**:
移行元 `users.id` と vps-rails `users.id` は一致しないため、`email` をキーに
vps-rails 側 `User` へマッピングし直す。生 `INSERT` は known_issues のバグ
(NULL `end_time` 表示不可・`event_params` 二重定義など)由来の不正データを
無検証のまま持ち込むリスクがあるため使わず、**モデル経由(`Reservation::Event.create!`)**
でバリデーションを通してインポートする。

手順:

1. [ ] `reservation_events` マイグレーションを適用済みにする(§4-1)
2. [ ] 移行元 DB から `events` と `users` を `email` 付きで CSV エクスポートする
   (移行元は独自 `users` テーブルを持つため、`user_id` ではなく `email` を
   経由させる必要がある)

   ```bash
   sqlite3 -header -csv db/production.sqlite3 "
     SELECT
       events.title, events.start_time, events.end_time,
       events.has_end_time, events.content,
       users.email AS user_email
     FROM events
     JOIN users ON users.id = events.user_id
   " > reservation_events_import.csv
   ```

3. [ ] CSV を vps-rails 側の作業ディレクトリに配置する(個人情報を含むため
   `.gitignore` 対象にし、リポジトリにはコミットしない)
4. [ ] `lib/tasks/reservation_import.rake` を作成し、以下の処理を行う:
   - CSV を1行ずつ読み込む
   - `user_email` で vps-rails 側 `User.find_by(email: row["user_email"])` を
     引く。見つからない行は **スキップしてログに記録**する
     (vps-rails 側でまだ一度もログインしていないユーザーのデータは
     移行できない旨をサマリで報告する)
   - `Reservation::Event.new(title:, start_time:, end_time:, has_end_time:, content:, user: user)`
     を組み立て、モデルのバリデーションを通して `save!` する
   - 移行データは過去日時の予定が大半を占める想定のため、`on: :create` の
     「過去日時禁止」バリデーションだけを import 時に迂回できるようにする
     (例: `Reservation::Event` に一時属性 `attr_accessor :skip_past_validation`
     を持たせ、`validate ... unless: :skip_past_validation` とする。
     通常のコントローラ経由の作成では使用しない、import タスク専用のフラグ)
   - タイトル必須/50字・終了時刻整合性などの**それ以外のバリデーションは
     import でも有効なまま**にする(不正データはそのままエラーとして記録し、
     処理は止めずに次の行へ進める)
5. [ ] 冪等性の確保: rake タスクの先頭で `Reservation::Event.exists?` を
   チェックし、既にデータが1件でもあれば実行前に確認を求める
   (二重実行による重複投入を防ぐ簡易ガード)
6. [ ] 実行後、「移行元件数 / 成功件数 / スキップ件数 / エラー件数」の
   サマリを出力する
7. [ ] 開発 or ステージング環境でリハーサル実行し、件数・サンプルデータを
   確認してから本番実行する

---

## §5. 実装順序(チェックリスト)

### Phase 0: 骨組み
- [ ] §3 の内容一式

### Phase 1: モデル
- [ ] `Reservation::Event` 作成(バリデーション: タイトル必須/50字、
      開始時刻必須、作成時のみ過去日時禁止、終了時刻は開始時刻より後
      〈同時刻も不可〉)
- [ ] known_issues #1 のバグ(`end_time` NULL がカレンダーに出ない)を
      再発させないクエリ設計をこの段階で確定する
      (`(end_time IS NULL OR end_time >= ?)`)
- [ ] モデルテスト

### Phase 2: ルーティング + コントローラ骨格
- [ ] `Reservation::BaseController`
- [ ] `Reservation::EventsController`(index/new/create/edit/update/destroy、
      `current_user.reservation_events` スコープで認可。known_issues #2 の
      `event_params` 二重定義は最初から1箇所のみ定義して再発させない)

### Phase 3: ビュー・カレンダー UI(確定事項 a)
- [ ] FullCalendar を importmap で pin
- [ ] サーバー側でイベントデータを描画し DOM(`<script type="application/json">`)
      に埋め込み、Stimulus コントローラ経由で FullCalendar に渡す
- [ ] モーダルフォーム(新規作成・編集)、Turbo Frame で開く
- [ ] 祝日色分け(`holiday_jp`、土曜=青、日曜・祝日=赤)
- [ ] 終了時刻自動補完(Stimulus `reservation--time-sync`)

### Phase 4: リアルタイム更新(確定事項 f)
- [ ] `turbo_stream_from "reservation_events_user_#{current_user.id}"` を
      カレンダービューに設置
- [ ] 作成・更新・削除後に `Turbo::StreamsChannel.broadcast_*_to` で
      当該ユーザーの他タブへ配信
- [ ] FullCalendar は Turbo Stream で届いたデータを Stimulus 側で
      `calendar.refetchEvents()` 相当の API で反映する
      (Turbo Stream の DOM 置換だけでは FullCalendar の内部状態が
      更新されないため、Stimulus 側でのブリッジ処理が必要)

### Phase 5: データ移行(確定事項 e)
- [ ] §4-2 の手順を実施

### Phase 6: テスト
- [ ] モデル/コントローラテスト一式
- [ ] known_issues 全項目に対する「踏襲していないことの確認」チェックリスト消化
      (#1 NULL end_time, #2 event_params 二重定義, #3 不要 GET ルート,
      #4 show 認可漏れ, #10 開発環境自動ログイン, #12 User 一意性
      〈vps-rails は `validates :uid, uniqueness: { scope: :provider }` 済みのため対応不要〉)

---

## §6. 後続フェーズ TODO(今回のスコープ外)

- PWA 対応(manifest.json / service worker)。確定事項 g により今回は
  着手しないが、破棄はしない。移行元の `app/views/pwa/` 相当を
  参考に後続フェーズで実装する
- 機能選択のランディングページ(root 導線の見直し。確定事項 c)
