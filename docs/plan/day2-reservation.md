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

- [x] `Gemfile` に `gem "holiday_jp"` を追加し `bundle install`
- [x] `config/routes.rb` に `namespace :reservation do resources :events, except: [:show] end` を追加(既存 `kaikei` ブロックは変更しない)
- [x] `app/models/reservation/` ディレクトリを作成
- [x] `app/controllers/reservation/base_controller.rb`(`layout "reservation"`)を作成 — `Kaikei::BaseController` と同型
- [x] `app/views/layouts/reservation.html.erb` を作成 — `kaikei.html.erb` と同型(`render template: "layouts/application"` で内側から包む)
- [x] `app/views/reservation/shared/_header.html.erb` を作成
- [x] `app/javascript/controllers/reservation/` ディレクトリを作成(kaikei の toast コントローラに名前空間をまたいで依存しないよう `reservation--toast` を新規作成)
- [x] `app/models/user.rb` に `has_many :reservation_events, class_name: "Reservation::Event", dependent: :destroy` を1行追記(既存 kaikei 関連行は変更しない)
- [x] `test/controllers/reservation/`, `test/models/reservation/` ディレクトリ、`test/fixtures/reservation_events.yml` を作成
- [x] `config/application.rb` に `config.time_zone = "Tokyo"` を追加(確定事項 b。kaikei にも影響する全体変更である旨をコミットメッセージ等に明記する)
- [x] `bin/importmap pin` で FullCalendar 関連パッケージ(core / daygrid / timegrid / interaction)を取り込む。jspm の内部チャンク分割(`internal.js` 等の相対 import)がフラット vendoring と相性が悪く自動 pin だけでは解決しなかったため、`@fullcalendar/core/internal.js` 等のサブパスと `preact` 一式を個別に pin し、vendor 済みファイル内の相対 import を bare specifier に手動で書き換えて解決した(`config/importmap.rb` 参照)

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

- [x] マイグレーションファイル作成
- [x] `rails db:migrate`

### §4-2. 既存データ移行(確定事項 e)

**方針変更(kaikei の移行と同じ形に統一)**: email 経由で行ごとに
vps-rails 側ユーザーへマッピングする方式は廃止した。移行元は複数ユーザーの
データを持つが、実際に移行する必要があるのは移行元アカウント1件(42件)のみ
(残りは vps-rails 側で一度もログインしていないユーザーのデータで、
移行対象外)。投入先はこのアプリの利用者本人である `User` 1件に固定する。
これにより「vps-rails 側に未ログインのためスキップ」という問題自体が
発生しなくなる(kaikei 移行の `KAIKEI_MIGRATION_EMAIL` 固定と同型)。
メールアドレスは git 管理対象のファイルに直書きしないため、以下では
移行元アカウントを「移行元アカウント」、投入先アカウントを「投入先アカウント」
と表記する(実際のメールアドレスは実行時に環境変数で渡す)。

生 `INSERT` は known_issues のバグ(NULL `end_time` 表示不可・`event_params`
二重定義など)由来の不正データを無検証のまま持ち込むリスクがあるため使わず、
引き続き**モデル経由(`Reservation::Event.new` + `save`)**でバリデーションを
通してインポートする。

手順:

1. [x] `reservation_events` マイグレーションを適用済みにする(§4-1)
2. [x] 移行元 DB から移行元アカウントの `events` のみを CSV エクスポートする。
   投入先ユーザーが固定のため `user_email` 列は不要(`WHERE` で対象ユーザーに
   絞り込み、`users` との JOIN は絞り込み条件のためだけに使い、SELECT には
   含めない)

   ```bash
   sqlite3 -header -csv db/production.sqlite3 "
     SELECT
       events.title, events.start_time, events.end_time,
       events.has_end_time, events.content
     FROM events
     JOIN users ON users.id = events.user_id
     WHERE users.email = '<移行元アカウントのメールアドレス>'
   " > reservation_events_import.csv
   ```

3. [x] CSV を vps-rails 側の作業ディレクトリ(`ignore/`)に配置する
   (個人情報を含むため `.gitignore` 対象にし、リポジトリにはコミットしない。
   本番では Docker イメージにも焼かないよう `.dockerignore` に `/ignore/`
   を追加済み。本番投入時は CSV を scp でボリュームか一時パスに置き、
   `kamal app exec` でそのファイルパスを `RESERVATION_IMPORT_CSV_PATH` に
   渡して読ませる想定)
4. [x] `lib/tasks/reservation_import.rake` を次の仕様に修正した:
   - 投入先 `User` は行ごとに email から引かず、環境変数
     `RESERVATION_IMPORT_TARGET_EMAIL` で指定した1アカウントに固定して
     `User.find_by(email: ...)` で取得する(メールアドレスをコードに
     直書きしない)。未設定または見つからなければ即 `abort`
   - CSV 全行を、その `User` に紐づけて `Reservation::Event.new(...).save`
   - 日時は UTC 保存前提で `Time.find_zone("UTC").parse(...)` で読む
     (`Time.zone.parse` だと JST 誤解釈になるため)。パースに失敗した行は
     スキップしてログに記録し、処理は継続する
   - `on: :create` の「過去日時禁止」バリデーションだけ import 時に迂回する
     (`skip_past_validation` フラグ、既存のまま)。タイトル必須/50字・
     終了時刻整合性などの**それ以外のバリデーションは import でも有効な
     まま**にする(不正データはエラーとして記録し、処理は止めずに次の行へ)
5. [x] 冪等性の確保: rake タスクの先頭で `Reservation::Event.exists?` を
   チェックし、既にデータが1件でもあれば実行前に確認を求める
   (二重実行による重複投入を防ぐ簡易ガード。`RESERVATION_IMPORT_FORCE=1`
   で明示的に上書き実行可能)
6. [x] 実行後、「対象件数 / 成功件数 / スキップ件数(日時パース不能) /
   エラー件数(バリデーション失敗)」のサマリを出力する
7. [x] 開発環境でリハーサル実行し、42件全件が投入先アカウントの `User` に
   紐づくこと(他ユーザー分は0件)、日時が UTC 保存 → JST 表示
   で正しく変換されること(例: CSV `2026-05-17 01:00:00` →
   `start_time.in_time_zone` で `2026-05-17 10:00:00 +0900`)を確認した。
   成功42件・スキップ0件・エラー0件。再実行時に冪等性ガードが働き
   `RESERVATION_IMPORT_FORCE=1` なしでは中止されること(件数が84件に
   増えないこと)も確認済み。リハーサル後は開発DBのデータを削除し
   クリーンな状態に戻した。本番実行は Phase 6 完了・全体の GO 判断後に
   一度だけ実施する(未実施)

---

## §5. 実装順序(チェックリスト)

### Phase 0: 骨組み
- [x] §3 の内容一式

### Phase 1: モデル
- [x] `Reservation::Event` 作成(バリデーション: タイトル必須/50字、
      開始時刻必須、作成時のみ過去日時禁止、終了時刻は開始時刻より後
      〈同時刻も不可〉)。マイグレーション(§4-1)も作成・適用済み
      (fixture が参照するテーブルが存在しないとテストスイート全体が
      壊れるため、Phase 0 の直後に前倒しで実施)
- [x] known_issues #1 のバグ(`end_time` NULL がカレンダーに出ない)を
      再発させないクエリ設計をこの段階で確定する
      (`(end_time IS NULL OR end_time >= ?)`、`Reservation::Event.within_range` スコープとして実装)
- [x] モデルテスト(`test/models/reservation/event_test.rb`、known_issues #1 の回帰テスト含む)

### Phase 2: ルーティング + コントローラ骨格
- [x] `Reservation::BaseController`
- [x] `Reservation::EventsController`(index/new/create/edit/update/destroy、
      `current_user.reservation_events` スコープで認可。known_issues #2 の
      `event_params` 二重定義は最初から1箇所のみ定義して再発させない)。
      コントローラテスト一式(他ユーザーのイベントへの edit/update/destroy が
      404 になることの検証を含む)。ビューは暫定の一覧・フォーム表示のみで、
      FullCalendar 統合は Phase 3 で行う

### Phase 3: ビュー・カレンダー UI(確定事項 a)
- [x] FullCalendar を importmap で pin(§3 で実施済み)
- [x] サーバー側でイベントデータを描画し DOM(`<script type="application/json">`)
      に埋め込み、Stimulus コントローラ(`reservation--calendar`)経由で
      FullCalendar に渡す。`"/"` を `"\/"` にエスケープして `</script>` による
      タグ分断を防止
- [x] モーダルフォーム(新規作成・編集)、Turbo Frame(`#modal`)で開く。
      日付クリック/イベントクリックは JS 側で非表示リンクの href を書き換えて
      クリックする方式(`data-turbo-frame="modal"`)で実装。フォーム送信は
      `data-turbo-frame="_top"` でフレームを離脱しフルページ遷移させ、
      作成・更新・削除直後にカレンダー全体を最新化する(Phase 4 の
      Turbo Streams 配信が入るまでの暫定挙動として、同一タブ内は
      これで完結する)
- [x] 祝日色分け(`holiday_jp`、土曜=青、日曜・祝日=赤)。祝日データは
      前後1年を含む3年分を `HolidayJp.between` で events#index で計算し
      DOM に埋め込み、`dayCellClassNames` で判定
- [x] 終了時刻自動補完(Stimulus `reservation--time-sync`)

備考: `bin/importmap pin @fullcalendar/...` だけでは jspm の内部チャンク
分割(`internal.js` 等の相対 import)がフラット vendoring と衝突し解決
しきれなかったため、サブパスの個別 pin + vendor ファイル内の相対 import
書き換えで対応した(詳細は §3 の備考、`config/importmap.rb` を参照)。
実機ブラウザでの検証環境(chromium-cli 等)がサンドボックス内で利用
できなかったため、`ActionDispatch::Integration::Session` を使った
実 HTTP リクエストベースでの動作確認(ログイン→作成→カレンダー JSON への
反映→編集画面表示→削除→JSON から消えることを確認)で代替した。
ブラウザでの視覚的な確認(カレンダー描画・モーダル開閉・祝日色分けの
見た目)は未実施のため、実機での確認を推奨する。

### Phase 4: リアルタイム更新(確定事項 f)
- [x] `turbo_stream_from "reservation_events_user_#{current_user.id}"` を
      カレンダービューに設置
- [x] 作成・更新・削除後に `Turbo::StreamsChannel.broadcast_replace_to` で
      当該ユーザーの他タブへ配信(`events_controller.rb#broadcast_calendar_refresh`)。
      イベント一覧全体を JSON 化して `<script id="reservation-calendar-events">`
      タグを丸ごと差し替える方式(`update` ではなく `replace` を使用 — `update`
      だと同一 DOM ノードの中身だけが変わり Stimulus の targetConnected が
      発火しないため、`replace` でノード自体を再生成させる必要がある)
- [x] FullCalendar は Turbo Stream で届いたデータを Stimulus 側で反映する。
      `events.json` のような fetch API は存在しないため
      `calendar.refetchEvents()` は使わず、Stimulus の
      `eventsTargetConnected(element)` ライフサイクルコールバックで
      新しい `<script>` の中身を読み、`removeAllEventSources` +
      `addEventSource` で FullCalendar 内部の状態を差し替えるブリッジ処理を
      実装した
- [x] コントローラテストに `assert_turbo_stream_broadcasts` /
      `assert_no_turbo_stream_broadcasts` を追加(作成・更新・削除で配信、
      バリデーション失敗時は配信しないことを検証)。実ブラウザでの
      複数タブ間リアルタイム反映は未検証(サンドボックス内にブラウザ
      環境がないため)。ペイロード形状(`action="replace"`、正しい
      `target`、再生成後の `<script>` に全イベントが含まれること)は
      サーバーサイドで直接確認済み

### Phase 5: データ移行(確定事項 e)
- [x] §4-2 の手順を実施(開発環境でのリハーサルまで完了。本番投入は
      Phase 6 完了・全体の GO 判断後に一度だけ実施する)

### Phase 6: テスト
- [x] モデル/コントローラテスト一式(`bin/rails test` 全体で 58 runs, 0
      failures, 0 errors。うち reservation 配下は 22 runs)
- [x] known_issues 全項目に対する「踏襲していないことの確認」チェックリスト消化
      - #1 NULL end_time: `Reservation::Event.within_range` スコープ
        (`(end_time IS NULL OR end_time >= ?)`)は実装・回帰テスト済み。
        ただし `events_controller#index` は範囲指定なしで
        `current_user.reservation_events.order(:start_time)`(全件)を
        DOM に埋め込む設計のため、実際には `within_range` を呼び出して
        いない(呼び出し元なし=未使用コード)。バグとしては発生しない
        (絞り込み自体がないため)。個人利用規模では全件表示のままで
        性能上問題にならないと判断し、`index` への組み込みは行わない
        (ユーザー確認済み)。スコープ・回帰テストは将来の拡張に備えて
        残す
      - #2 event_params 二重定義: `events_controller.rb` に1箇所のみ定義。
        再発なし
      - #3 不要 GET ルート: `sessions/new|create|destroy` の GET ルートは
        存在しない(vps-rails 側は元々このルートを持たない設計)
      - #4 show 認可漏れ: `resources :events, except: [:show]` により
        `show` アクション自体が存在しない
      - #10 開発環境自動ログイン: 該当コードなし
      - #12 User 一意性: vps-rails は
        `validates :uid, uniqueness: { scope: :provider }` 済みのため
        対応不要

---

## §6. 後続フェーズ TODO(今回のスコープ外)

- PWA 対応(manifest.json / service worker)。確定事項 g により今回は
  着手しないが、破棄はしない。移行元の `app/views/pwa/` 相当を
  参考に後続フェーズで実装する
- 機能選択のランディングページ(root 導線の見直し。確定事項 c)
