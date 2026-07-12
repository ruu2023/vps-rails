# business_logic.md — ビジネスロジック仕様 (as-is)

## 予約の重複チェック

**実装なし。**

同一ユーザーが同じ時間帯に複数のイベントを作成できる。複数ユーザー間の重複チェックも存在しない。

---

## ドメインルール一覧

### 1. イベント作成時の過去日時禁止

- **実装**: `app/models/event.rb` — `start_time_cannot_be_in_the_past`
- **条件**: `on: :create` のみ（更新時は過去日時でも保存可能）
- **比較**: `start_time < Time.zone.now`（Asia/Tokyo）

### 2. 終了時刻 > 開始時刻

- **実装**: `app/models/event.rb` — `end_time_cannot_be_before_start_time`
- **条件**: `end_time <= start_time` の場合エラー（同一時刻も不可）
- **条件**: `end_time` が存在して `start_time` が未入力の場合もエラー
- **更新時も適用**（`on:` 制限なし）

### 3. タイトル必須 / 最大50文字

- **実装**: `app/models/event.rb` — `validates :title, presence: true, length: { maximum: 50 }`

### 4. 開始時刻必須

- **実装**: `app/models/event.rb` — `validates :start_time, presence: true`

### 5. 終了時刻の省略

- `has_end_time: false`（デフォルト）の場合、`end_time` は NULL でも保存可能
- UI では `has_end_time` チェックボックスをオンにすると終了時刻入力欄が表示される
- **実装**: `app/views/events/_modal_form.html.erb`、`app/javascript/controllers/time_sync_controller.js`

### 6. 終了時刻の自動補完

- `start_time` を変更すると `end_time` が自動的に1時間後にセットされる
- **実装**: `app/javascript/controllers/time_sync_controller.js`

### 7. イベントの所有者チェック

- `events#index`（JSON）: `current_user.events.where(...)` で自分のイベントのみ取得
- `events#edit/update/destroy`: `set_event` が `current_user.events.find(params[:id])` → 他ユーザーのイベントに触れない（見つからず 404）
- **実装**: `app/controllers/events_controller.rb` — `set_event`, `index`

### 8. 認証ガード

- `events` コントローラ全アクションに `before_action :authenticate_user!`
- 未ログインはルートにリダイレクト（アラート付き）
- **実装**: `app/controllers/application_controller.rb` — `authenticate_user!`

### 9. カレンダー表示範囲

- FullCalendar から `?start=...&end=...` で範囲指定。`start_time <= range_end AND end_time >= range_start` で抽出
- `end_time` が NULL のイベントはこのクエリにマッチしない（`end_time >= range_start` が NULL で false）
- **実装**: `app/controllers/events_controller.rb` — `index`

### 10. 新規作成時のデフォルト時刻

- カレンダーの日付をクリックすると `?date=YYYY-MM-DD` 付きで `new` が開く
- デフォルト: `start_time = 10:00`、`end_time = 11:00`（その日の Asia/Tokyo 時刻）
- **実装**: `app/controllers/events_controller.rb` — `new`

### 11. リアルタイム更新

- 作成・更新・削除後、`Turbo::StreamsChannel.broadcast_append_to` でカレンダーをリフレッシュ
- チャンネル名: `"events_user_#{event.user_id}"`（ユーザー単位）
- **実装**: `app/controllers/events_controller.rb` — `broadcast_calendar_refresh`

---

## 定員・キャンセル・承認フロー

**実装なし。** これらの概念はデータモデルに存在しない。
