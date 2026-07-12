# known_issues.md — 既知の問題・移植時修正対象 (as-is)

移植時にはこれらを踏襲せず修正する。

---

## バグ

### 1. `end_time` が NULL のイベントがカレンダーに表示されない

- **場所**: `app/controllers/events_controller.rb` — `index` アクション
- **コード**:
  ```ruby
  @events = current_user.events.where(
    "start_time <= ? AND end_time >= ?", range_end, range_start
  )
  ```
- **問題**: `end_time` が NULL のレコードは `end_time >= range_start` が false になりカレンダーに表示されない。`has_end_time: false` のイベント（終了時刻なし）が意図的にサポートされているにもかかわらず表示できない。
- **修正方針**: `(end_time IS NULL OR end_time >= ?)` に変更する。

### 2. `event_params` が二重定義

- **場所**: `app/controllers/events_controller.rb`
- **コード**: `event_params` メソッドが同ファイルに2回定義されている。Ruby は後の定義を使うため、`:has_end_time` を含む2つ目の定義が実際に呼ばれる。1つ目は完全に無効。
- **修正方針**: 重複を削除し、正しい1つにまとめる。

---

## 認可漏れ

### 3. `sessions_controller` の GET ルートに認可不要の意図しないアクセスポイント

- **場所**: `config/routes.rb`
- **コード**:
  ```ruby
  get "sessions/new"
  get "sessions/create"
  get "sessions/destroy"
  ```
- **問題**: `sessions/create` と `sessions/destroy` に GET でアクセスできるが、これらは OmniAuth コールバックとログアウト用に別途定義されている。GET の `sessions/create` にアクセスすると `request.env["omniauth.auth"]` が nil になり nil エラーまたは不正なユーザー生成につながる恐れがある。GET の `sessions/destroy` はログアウト処理が GET でも実行されてしまう（CSRF リスク）。
- **修正方針**: この3行を削除する。実際の認証フローは `/auth/:provider/callback` と `DELETE /logout` で完結している。

### 4. ログインユーザーが他者のイベントを `show` で閲覧できる可能性

- **場所**: `config/routes.rb` + `app/controllers/events_controller.rb`
- **問題**: `resources :events` により `GET /events/:id` (`show` アクション) が生成されるが、コントローラに `show` アクションは実装されていない。アクセスするとテンプレートが見つからずエラー。ただし、将来 `show` を追加する際に `set_event` に `current_user` スコープを忘れると他ユーザーのイベントを閲覧できてしまう。
- **修正方針**: 不要なら `resources :events, except: [:show]` に変更する。

---

## 未完成箇所

### 5. メーラー未実装

- **場所**: `app/mailers/application_mailer.rb`（ベースクラスのみ）
- `from` は `"from@example.com"` のままでデフォルト値が残っている。予約確認・キャンセルのメール送信機能は存在しない。

### 6. ActiveStorage 利用実態が不明

- `image_processing` gem が Gemfile に含まれるが、モデルへの `has_one_attached` / `has_many_attached` の定義が見当たらない。将来用に追加されたか、使用されていない可能性がある。

### 7. `jbuilder` 利用なし

- `app/views/events/*.json.jbuilder` が存在せず、`index` の JSON は `render json:` でインラインで書かれている。gem が不要な可能性がある。

### 8. シードデータが本番向けでない

- **場所**: `db/seeds.rb`
- サンプルイベントが `user_id: 1` を直接指定して作成される。本番 DB で `rails db:seed` を実行すると不正な参照またはデータ汚染が起きる。

### 9. CSP 設定が無効化されている

- **場所**: `config/initializers/content_security_policy.rb`
- 全内容がコメントアウトされており、CSP が機能していない。FullCalendar を CDN から読み込んでいる関係で設定が難しいが、移植時には適切な CSP を設定すべき。

---

## 非推奨・懸念のある実装

### 10. 開発環境自動ログインが本番に漏れるリスク

- **場所**: `app/controllers/application_controller.rb` — `authenticate_user!`
- **コード**:
  ```ruby
  def authenticate_user!
    if Rails.env.development? && !logged_in?
      auto_login_for_dev
    end
    unless logged_in?
      redirect_to root_path, alert: "ログインが必要です"
    end
  end
  ```
- `Rails.env.development?` でガードされているため即座に本番漏れはしないが、環境変数の設定ミスで本番に影響する可能性がある。移植時には削除する。

### 11. `config/secrets.yml` の存在

- Rails 5.2 以降では `credentials.yml.enc` が標準。`secrets.yml` が残っている場合、機密情報の二重管理になる可能性がある（ファイル内容は未確認）。

### 12. `User` バリデーションなし

- `provider` + `uid` の複合インデックスがなく、`validates_uniqueness_of` も未定義。`first_or_create` に並行リクエストが来ると重複ユーザーが作成される可能性がある（race condition）。

### 13. FullCalendar を CDN から読み込み

- `app/views/layouts/application.html.erb` で `unpkg.com` から FullCalendar 6.1.15 を読み込んでいる。CDN 障害・バージョン変更でアプリが壊れるリスクがある。importmap での管理に移行することを推奨。
