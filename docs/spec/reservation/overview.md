# overview.md — アプリ現状仕様 (as-is)

## アプリの目的

個人カレンダー兼イベント管理アプリ。Google OAuth でログインしたユーザーが自分の予定（イベント）を登録・編集・削除し、月次カレンダービューで管理する。

「予約(reservation)」という名称だが、実態は **個人スケジュール管理** であり、複数ユーザー間の重複チェック・定員管理・承認フローなどの予約システム的な機能は現時点では存在しない。

---

## 主要ユースケース

| # | ユースケース | 概要 |
|---|---|---|
| 1 | ログイン | Google OAuth2 でサインイン |
| 2 | カレンダー閲覧 | 月次表示で自分の予定一覧を見る |
| 3 | 予定の作成 | タイトル・開始時刻・終了時刻・内容を入力して登録 |
| 4 | 予定の編集 | カレンダー上のイベントをクリックしてモーダルで編集 |
| 5 | 予定の削除 | モーダルの削除ボタンで即削除 |
| 6 | ログアウト | セッションを破棄してログイン画面へ |

---

## 画面一覧

| URL | HTTPメソッド | コントローラ#アクション | 役割 |
|---|---|---|---|
| `/` | GET | `sessions#new` | ログイン画面（root） |
| `/auth/google_oauth2/callback` | GET | `sessions#create` | OmniAuth コールバック、セッション確立 |
| `/logout` | DELETE | `sessions#destroy` | ログアウト |
| `/events` | GET | `events#index` | カレンダービュー（HTML） |
| `/events.json` | GET | `events#index` | FullCalendar 用 JSON API（クエリ: `start`, `end`） |
| `/events/new` | GET | `events#new` | 新規予定フォーム（モーダル、クエリ: `date`） |
| `/events` | POST | `events#create` | 予定作成 |
| `/events/:id/edit` | GET | `events#edit` | 編集フォーム（モーダル） |
| `/events/:id` | PATCH/PUT | `events#update` | 予定更新 |
| `/events/:id` | DELETE | `events#destroy` | 予定削除 |
| `/up` | GET | `rails/health#show` | ヘルスチェック |

### カレンダービューの特徴

- FullCalendar 6.1.15（CDN）で月次表示
- 祝日は `holiday_jp` gem で取得し、日本の祝日を赤色表示
- 土曜は青色、日曜・祝日は赤色
- イベントクリック → `edit` パスを `turbo-frame#modal` で開く
- 日付クリック → `new?date=YYYY-MM-DD` を同モーダルで開く
- 保存・削除後は Turbo Streams でカレンダーをリフレッシュ（ページ遷移なし）

---

## 非機能的な特徴

- **PWA 対応**: `manifest.json`・Service Worker あり
- **タイムゾーン**: Asia/Tokyo 固定
- **週始まり**: 日曜日
- **開発環境自動ログイン**: `dev@example.com` ユーザーを自動生成してログイン
