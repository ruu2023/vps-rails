# kaikei（会計アプリ）新規実装計画

## Context

`vps-rails` は複数機能をパス名前空間で同居させる個人開発用モノリス(`.claude/CLAUDE.md`参照)。今回、`docs/spec/`にあるLaravel製会計アプリの仕様書を元に、Rails 8 + Hotwireで`/kaikei`名前空間の会計アプリを新規実装する。

現在のRailsアプリはRails 8の素の雛形のまま(認証機構・User モデル・ルーティングは未生成、`root`はプレースホルダ、Gemfileにbcrypt/omniauth系gemなし)。ゼロから構築する。

`/grill-me`での対話を通じて、Laravel版の仕様を「バグごと踏襲」するのではなく、認可漏れ・型不整合・未完成機能を修正しながら再実装する方針を確定した。主要決定はCLAUDE.mdに反映済み。この計画はその決定に基づく実装手順。

## 全体方針(確定事項の要約)

- 忠実な移植ではなく、既知のバグを修正しながらクリーンに再実装
- 認証: Google OAuthのみ(Rails標準メール/パスワード認証は使わない)、登録制限なし
- 科目・支払方法はユーザーごとに分離、初期状態は空
- 取引先(Client)マスタは作らず自由テキストのみ
- 科目のみ論理削除、他は物理削除
- 消費税計算なし、i18nなし、タイムゾーンJST固定
- フロントは全面Hotwire化、Chart.jsはimportmap経由
- エクスポートはサーバーサイド生成(CSV/Excel)に統一
- テストはminitest

## 1. Gemfile / 依存追加

- `gem "omniauth-google-oauth2"` , `gem "omniauth-rails_csrf_protection"` — Google OAuthログイン
- `gem "caxlsx"` — サーバーサイドExcel生成(エクスポート機能用)
- Ruby標準の`CSV`はGemfile追加不要

`config/credentials.yml.enc`にGoogle OAuth の `client_id`/`client_secret` を追加(`bin/rails credentials:edit`で対応、実装時に案内)。

## 2. 認証(トップレベル、名前空間なし)

- `User`モデル(`app/models/user.rb`): `email`, `name`, `avatar_url`, `provider`, `uid`(Google識別子でfind_or_create)
- マイグレーション: `users`テーブル(`provider`+`uid`にunique index)
- `SessionsController`(`app/controllers/sessions_controller.rb`): `create`(omniauthコールバックで`User.find_or_create_by`)、`destroy`(ログアウト)
- `config/initializers/omniauth.rb`でGoogle OAuth2ストラテジー設定
- `ApplicationController`に`current_user`/`authenticate_user!`のconcern(`app/controllers/concerns/authentication.rb`)を追加、`before_action :authenticate_user!`をデフォルトに
- ルーティング: `get "auth/google_oauth2/callback" => "sessions#create"`, `delete "logout" => "sessions#destroy"`, `get "login" => "sessions#new"`

## 3. DBスキーマ(kaikei名前空間、テーブルは`kaikei_`プレフィックス)

CLAUDE.md規約通り、モデルは`Kaikei::`名前空間 + `self.table_name`で明示。

- `kaikei_categories`: `user_id`(FK, NOT NULL), `name`, `icon`(nullable), `default_type`(string, check制約でincome/expense), `sort_order`(integer, default 0), `deleted_at`(nullable, 論理削除), `created_at`/`updated_at`
- `kaikei_payment_methods`: `user_id`(FK, NOT NULL), `name`, `type`(string, check制約でincome/expense), `created_at`/`updated_at`
- `kaikei_transactions`: `user_id`(FK, NOT NULL), `category_id`(FK, NOT NULL), `payment_method_id`(FK, nullable, `dependent: :nullify`相当の外部キーオプション), `date`, `amount`(integer, `>= 0`のDBチェック制約), `type`(string, check制約income/expense), `client_name`(string, nullable), `memo`(text, nullable), `created_at`/`updated_at`
- `kaikei_budgets`: `user_id`(FK, NOT NULL), `category_id`(FK, NOT NULL), `amount`(integer, `>= 1`), `year`(integer), `month`(integer, 1〜12), `created_at`/`updated_at`。ユニーク制約`[user_id, category_id, year, month]`

外部キーは`foreign_key: true`で作成。`payment_method_id`は`on_delete: :nullify`。

## 4. モデル

- `Kaikei::Category`
  - `belongs_to :user`, `has_many :transactions`, `has_many :budgets`
  - 論理削除: `default_scope { where(deleted_at: nil) }` + `discard`インスタンスメソッド(`update(deleted_at: Time.current)`)。gemは使わず自前実装(規模的に`discard`/`paranoia`gem導入は過剰)
  - validates `default_type` inclusion in `%w[income expense]`
  - `sort_order`はcontroller側で`Category.maximum(:sort_order).to_i + 1`を採番(元仕様通り)

- `Kaikei::PaymentMethod`
  - `belongs_to :user`, `has_many :transactions, dependent: :nullify`
  - validates `type` inclusion in `%w[income expense]`

- `Kaikei::Transaction`
  - `belongs_to :user`, `belongs_to :category`, `belongs_to :payment_method, optional: true`
  - validates `amount`(integer, `>= 0`), `date`(presence), `type` inclusion
  - **カスタムバリデーション**: `type`が`category.default_type`と一致すること(質問21の決定)
  - スコープ: `for_month(year, month)`, `income`, `expense`

- `Kaikei::Budget`
  - `belongs_to :user`, `belongs_to :category`
  - validates `amount >= 1`, `month` 1〜12、`[user_id, category_id, year, month]`のuniqueness
  - **カスタムバリデーション**: `category.default_type == "expense"`であること(質問22)
  - アクセサ: `actual_spent`, `progress_percentage`(`.round(1)`で丸め、質問11)、`remaining_amount`, `over_budget?`, `warning_level`

## 5. コントローラ / ルーティング(`config/routes.rb`)

```ruby
namespace :kaikei do
  resource :dashboard, only: :show
  resources :transactions
  resources :categories
  resources :payment_methods
  resources :budgets
  resource :exports, only: [:new, :create]
end
```

- `Kaikei::BaseController < ApplicationController` — 名前空間共通の`before_action`(全て`current_user`スコープでレコード取得)
- `Kaikei::DashboardController#show` — 今月/先月収支、変化率、直近5件、6ヶ月推移、予算一覧(元のAppController@dashboard相当)
- `Kaikei::TransactionsController` — `index`(フィルタ: type/category/期間、ページネーションは`Kaminari`等新規gem導入せず簡易`limit`/`offset`実装)、`new`/`create`/`edit`/`update`/`destroy`
- `Kaikei::CategoriesController` — 標準CRUD、Turbo Stream対応、`destroy`は論理削除
- `Kaikei::PaymentMethodsController` — 標準CRUD
- `Kaikei::BudgetsController` — `index`(年月指定)、`create`(`find_or_initialize_by`でupdateOrCreate相当)、`update`、`destroy`
- `Kaikei::ExportsController#new`(フォーム)/`#create`(期間・出力項目・形式を受けてCSVまたはExcelを`send_data`で返す。CSVは標準`CSV`ライブラリ、Excelは`caxlsx`)

全コントローラで`current_user`スコープの`Kaikei::BaseController`を継承し、他ユーザーのレコードへの操作は`ActiveRecord::RecordNotFound`(`current_user.categories.find(params[:id])`パターン)で自然に防ぐ。

## 6. ビュー / Stimulus / Turbo Streams

- レイアウト: `app/views/layouts/application.html.erb`に共通ナビゲーション(ダッシュボード/取引/科目/支払方法/予算/エクスポート へのリンク)を追加
- 各リソースの`index`/`new`/`edit`フォームはTurbo Frame + Turbo Streamで部分更新(`create.turbo_stream.erb`等)
- Stimulusコントローラ: `app/javascript/controllers/kaikei/`配下
  - `chart_controller.js` — Chart.js初期化(ダッシュボード棒グラフ、分析画面円グラフ)、`data-*`属性でサーバーから系列データを受け取る
  - `transaction_form_controller.js` — 科目選択に応じた収支区分・支払方法の絞り込み(元のtransaction.jsのロジックを移植)
- `bin/importmap pin chart.js` でChart.jsをvendor化(CDN排除、質問14)

## 7. エクスポート実装

- `caxlsx`で`Kaikei::ExportsController#create`がExcel生成、標準`CSV.generate`でCSV生成(UTF-8 BOM付与)
- 出力項目「取引データ」「仕訳帳」の2種類(元の仕様通り)、仕訳帳は借方・貸方を収支区分で機械的に振り分け(税抜計算等はしない、質問5で対象外済み)
- 旧仕様にあった2経路の重複エクスポートは1つに統合済み(質問10)

## 8. テスト(minitest)

- `test/models/kaikei/*_test.rb` — 各モデルのバリデーション(特に`type`/`default_type`整合性、`amount`範囲、ユニーク制約)
- `test/controllers/kaikei/*_test.rb` — 認可(他ユーザーのレコードにアクセスできないこと)、CRUD正常系
- `test/fixtures/`にユーザー・科目・取引等のfixture追加
- 既存の`test/test_helper.rb`(parallelize, fixtures :all)をそのまま利用

## 9. 実装順序

1. Gemfile更新 + `bundle install`
2. 認証基盤(User, Sessions, omniauth設定、ApplicationControllerのauthentication concern)
3. マイグレーション一式(users, kaikei_categories, kaikei_payment_methods, kaikei_transactions, kaikei_budgets)
4. モデル実装 + モデルテスト
5. `Kaikei::BaseController` + 各リソースコントローラ + ルーティング
6. ビュー(index/new/edit) + レイアウト・ナビゲーション
7. ダッシュボード(集計ロジック + Chart.js Stimulusコントローラ)
8. エクスポート機能(CSV/Excel)
9. Turbo Stream化(科目・予算タブの部分更新)
10. コントローラテスト追加、`bin/rails test`で全体確認

## 検証方法

- `bin/rails db:migrate` でスキーマ適用
- `bin/rails test` でモデル/コントローラテストを実行
- `bin/dev`でサーバー起動し、ブラウザで以下を手動確認:
  - Googleログイン→ユーザー自動作成
  - 科目・支払方法の作成(ユーザーごとに分離されていること、別ユーザーでログインして見えないことを確認)
  - 取引登録(科目のdefault_typeと矛盾するtypeがバリデーションで弾かれること)
  - 予算作成(支出科目のみ選択可能、進捗率が小数第1位で丸められること)
  - ダッシュボードのグラフ表示(Chart.jsがCDNなしで動作)
  - エクスポート(CSV/Excelがダウンロードでき、内容が正しいこと)
