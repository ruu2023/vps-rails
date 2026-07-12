# routes.md — ルーティング仕様 (as-is)

## config/routes.rb 全ルーティング

```ruby
Rails.application.routes.draw do
  get "sessions/new"
  get "sessions/create"
  get "sessions/destroy"
  get "up" => "rails/health#show", as: :rails_health_check
  root "sessions#new"

  get "/auth/:provider/callback", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  resources :events
end
```

## ルーティング一覧表

| HTTPメソッド | パス | コントローラ#アクション | 備考 |
|---|---|---|---|
| GET | `/` | `sessions#new` | ルート、ログイン画面 |
| GET | `/sessions/new` | `sessions#new` | 冗長（root と重複） |
| GET | `/sessions/create` | `sessions#create` | 不審（後述） |
| GET | `/sessions/destroy` | `sessions#destroy` | 不審（後述） |
| GET | `/auth/:provider/callback` | `sessions#create` | OmniAuth コールバック（実際の認証フロー） |
| DELETE | `/logout` | `sessions#destroy` | ログアウト |
| GET | `/events` | `events#index` | カレンダー画面、JSON 兼用 |
| GET | `/events/new` | `events#new` | 新規フォーム（モーダル） |
| POST | `/events` | `events#create` | 予定作成 |
| GET | `/events/:id/edit` | `events#edit` | 編集フォーム（モーダル） |
| GET | `/events/:id` | `events#show` | （`resources` で定義されるが未実装） |
| PATCH | `/events/:id` | `events#update` | 予定更新 |
| PUT | `/events/:id` | `events#update` | 予定更新 |
| DELETE | `/events/:id` | `events#destroy` | 予定削除 |
| GET | `/up` | `rails/health#show` | ヘルスチェック |

## 注意点

- `sessions/new`, `sessions/create`, `sessions/destroy` の GET ルートが `resources` 風に定義されているが、実際の認証フローは `/auth/:provider/callback` と `/logout` のみ使用する。これら3つは不要な定義（後述 `known_issues.md` 参照）。
- `events#show` は `resources :events` で自動生成されるが、コントローラにアクションが実装されていない（アクセスするとエラー）。
