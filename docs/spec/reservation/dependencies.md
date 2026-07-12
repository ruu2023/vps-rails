# dependencies.md — 依存関係と vps-rails ギャップ (as-is)

## Ruby / Rails バージョン

| 項目 | バージョン |
|---|---|
| Ruby | 3.4.7（`.ruby-version` より） |
| Rails | 8.1.3（`Gemfile` より） |

---

## Gemfile 主要 gem

| gem | バージョン指定 | 用途 |
|---|---|---|
| `rails` | ~> 8.1.3 | フレームワーク |
| `propshaft` | 指定なし | アセットパイプライン（Sprockets ではなく Propshaft） |
| `sqlite3` | >= 2.1 | DB |
| `puma` | >= 5.0 | Webサーバー |
| `importmap-rails` | 指定なし | JS 管理 |
| `turbo-rails` | 指定なし | Hotwire Turbo |
| `stimulus-rails` | 指定なし | Hotwire Stimulus |
| `jbuilder` | 指定なし | JSON ビュー（使用箇所は未確認） |
| `solid_cache` | 指定なし | DB バックキャッシュ |
| `solid_queue` | 指定なし | DB バックジョブキュー |
| `solid_cable` | 指定なし | DB バック Action Cable |
| `bootsnap` | 指定なし | 起動高速化 |
| `kamal` | 指定なし | デプロイ（Dockerfile あり） |
| `thruster` | 指定なし | HTTP キャッシュ/圧縮 |
| `image_processing` | ~> 1.2 | ActiveStorage 画像変換 |
| `tailwindcss-rails` | ~> 4.4 | CSS フレームワーク |
| `omniauth-google-oauth2` | 指定なし | Google OAuth2 認証 |
| `omniauth-rails_csrf_protection` | 指定なし | OmniAuth CSRF 対策 |
| `holiday_jp` | 指定なし | 日本の祝日データ |
| `debug` | dev/test | デバッグ |
| `bundler-audit` | dev/test | Gem 脆弱性監査 |
| `brakeman` | dev/test | 静的セキュリティ解析 |
| `rubocop-rails-omakase` | dev/test | コードスタイル |
| `web-console` | dev | 例外ページコンソール |
| `htmlbeautifier` | dev | HTML整形 |
| `capybara` | test | システムテスト |
| `selenium-webdriver` | test | ブラウザ自動化 |

---

## 外部依存の有無

| 依存 | 有無 | 備考 |
|---|---|---|
| Redis | なし | Solid Cache/Queue/Cable で代替 |
| Sidekiq | なし | Solid Queue を使用 |
| ActiveStorage | あり（Gemfile に含まれる） | 実際の利用箇所は不明（`image_processing` gem あり） |
| Action Mailer | 設定あり（`application_mailer.rb`） | 実際の送信処理は未実装 |
| Cron / Whenever | なし | `config/schedule.rb` 不在 |
| 外部API | Google OAuth2 のみ | `config/initializers/omniauth.rb` で設定 |
| FullCalendar | あり（CDN） | v6.1.15 を `unpkg.com` から読み込み |

---

## vps-rails 標準スタックとのギャップ一覧

| 項目 | rails-reservation (as-is) | vps-rails (標準) | ギャップ・対応方針 |
|---|---|---|---|
| Rails バージョン | 8.1.3 | Rails 8 | 同等。問題なし |
| DB | SQLite | SQLite | 同一。問題なし |
| フロントエンド | Hotwire + importmap | Hotwire + importmap | 同一 |
| CSS | Tailwind CSS Rails 4.4 | Tailwind CSS | 同一 |
| アセットパイプライン | **Propshaft** | 不明（要確認） | vps-rails が Sprockets なら要注意 |
| 認証 | OmniAuth Google OAuth2 + cookies | Google OAuth 一本化 | 方式は同じ。セッション管理（cookie vs session store）を統一 |
| User モデル | アプリ内に独自 User あり | トップレベル共有 User | reservation の User を削除し、共有 User を参照するよう移植 |
| ジョブキュー | Solid Queue | Solid Queue | 同一 |
| キャッシュ | Solid Cache | Solid Cache | 同一 |
| Action Cable | Solid Cable | Solid Cable | 同一 |
| テスト | minitest（capybara/selenium） | minitest | 同一。ただしシステムテストのみで単体テストは未整備 |
| カレンダーライブラリ | FullCalendar 6.1.15（CDN） | なし | CDN 依存を importmap 管理に移行するか判断が必要 |
| 祝日表示 | `holiday_jp` gem | なし | gem を vps-rails の Gemfile に追加が必要 |
| Devise | なし | なし | 問題なし |
| デプロイ | Kamal（Dockerfile あり） | 不明 | vps-rails 側の方針に合わせる |
| `jbuilder` | あり | 不明 | 実際の使用箇所が確認できない場合は削除検討 |
| `image_processing` | あり | 不明 | ActiveStorage 利用実態が不明。不要なら削除 |

---

## タイムゾーン設定

```ruby
# config/application.rb
config.time_zone = "Tokyo"
config.beginning_of_week = :sunday
config.i18n.default_locale = :ja
```

vps-rails 側のタイムゾーン設定と合わせる必要がある。
