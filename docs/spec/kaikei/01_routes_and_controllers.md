# ルーティングとコントローラ一覧

出典: `routes/web.php`, `routes/auth.php`

## アプリケーションルート（`routes/web.php`）

すべて `auth` ミドルウェアグループ内（未ログイン時はログイン画面へリダイレクト）。

| Method | URI | Controller@Action | Route名 | 備考 |
|---|---|---|---|---|
| GET | `/` | - | - | `/dashboard` へリダイレクト（`Route::redirect`） |
| GET | `/dashboard` | `AppController@dashboard` | `dashboard` | ダッシュボード画面 |
| GET | `/transaction` | `AppController@transaction` | `transaction` | 取引登録フォーム画面（クエリ `type` で収入/支出初期選択） |
| GET | `/analytics` | `AppController@analytics` | `analytics` | 取引一覧・分析画面 |
| GET | `/settings` | `AppController@settings` | `settings` | 設定画面（クエリ `page` でタブ切替） |
| POST | `/categories` | `CategoryController@store` | - | 科目作成 |
| PATCH | `/categories/{category}` | `CategoryController@update` | - | 科目更新 |
| DELETE | `/categories/{category}` | `CategoryController@destroy` | - | 科目削除（論理削除） |
| POST | `/payment-methods` | `PaymentMethodController@store` | - | `Route::resource(...)->only(['store','update','destroy'])` により生成 |
| PUT/PATCH | `/payment-methods/{payment_method}` | `PaymentMethodController@update` | - | 同上 |
| DELETE | `/payment-methods/{payment_method}` | `PaymentMethodController@destroy` | - | 同上 |
| POST | `/clients` | `ClientController@store` | - | 取引先作成 |
| DELETE | `/clients/{client}` | `ClientController@destroy` | - | 取引先削除 |
| POST | `/data-export` | `DataExportController@fetchData` | - | 期間指定でJSON取引データ返却（フロントのExcel/CSVエクスポート用） |
| POST | `/transaction` | `TransactionController@store` | - | 取引作成 |
| GET | `/transaction/{transaction}` | `TransactionController@show` | `transaction.show` | 取引詳細（JSON） |
| GET | `/transaction/{transaction}/edit` | `TransactionController@edit` | `transaction.edit` | 取引編集用データ（JSON） |
| PATCH | `/transaction/{transaction}` | `TransactionController@update` | - | 取引更新 |
| DELETE | `/transaction/{transaction}` | `TransactionController@destroy` | - | 取引削除 |
| GET | `/transaction/export` | `TransactionController@exportCsv` | `transaction.export` | 仕訳帳CSVエクスポート |
| POST | `/budgets` | `BudgetController@store` | `budgets.store` | `Route::resource('budgets', ...)->only(['store','update','destroy'])` により生成。`updateOrCreate` で作成/更新 |
| PUT/PATCH | `/budgets/{budget}` | `BudgetController@update` | `budgets.update` | 同上 |
| DELETE | `/budgets/{budget}` | `BudgetController@destroy` | `budgets.destroy` | 同上 |
| GET | `/budgets/data` | `BudgetController@getBudgetData` | `budgets.data` | 指定年月の予算一覧をJSONで返却（AJAX用） |
| GET | `/profile` | `ProfileController@edit` | `profile.edit` | プロフィール編集画面 |
| PATCH | `/profile` | `ProfileController@update` | `profile.update` | プロフィール更新 |
| DELETE | `/profile` | `ProfileController@destroy` | `profile.destroy` | アカウント削除 |

### ルート定義順序に関する検出事項（要確認・実機動作未検証）

`routes/web.php` では次の順序でルートが登録されている（41〜45行目）。

```
GET  transaction/{transaction}        → TransactionController@show   (41行目)
GET  transaction/{transaction}/edit   → TransactionController@edit   (42行目)
PATCH transaction/{transaction}       → TransactionController@update (43行目)
DELETE transaction/{transaction}      → TransactionController@destroy(44行目)
GET  transaction/export               → TransactionController@exportCsv (45行目、name: transaction.export)
```

Laravelのルーティングは登録順に最初にマッチしたものが採用されるため、`GET /transaction/export` へのリクエストは、より先に登録されている `GET /transaction/{transaction}` （41行目）に一致し、`{transaction}` パラメータの値として文字列 `"export"` が渡る可能性があります。この場合、暗黙のルートモデルバインディングが `id = 'export'` の `Transaction` を検索して失敗し、404（`ModelNotFoundException`）になると考えられます。
**要確認**: 実際にアプリケーションを起動してこの経路を検証していないため、上記はLaravelのルート解決仕様に基づく推定です。もし推定通りであれば、CSVエクスポート機能（`transaction.export`）はURL経路としては到達不能で、ビュー側で名前付きルート `route('transaction.export')` を使ってリンクを生成している場合のみ正しいURLが生成されます（`resources/views` 側の生成箇所は [04_frontend.md](04_frontend.md) を参照）。

## 認証ルート（`routes/auth.php`、Laravel Breeze標準構成）

### `guest` ミドルウェアグループ

| Method | URI | Controller@Action | Route名 |
|---|---|---|---|
| GET | `register` | `Auth\RegisteredUserController@create` | `register` |
| POST | `register` | `Auth\RegisteredUserController@store` | - |
| GET | `login` | `Auth\AuthenticatedSessionController@create` | `login` |
| POST | `login` | `Auth\AuthenticatedSessionController@store` | - |
| GET | `forgot-password` | `Auth\PasswordResetLinkController@create` | `password.request` |
| POST | `forgot-password` | `Auth\PasswordResetLinkController@store` | `password.email` |
| GET | `reset-password/{token}` | `Auth\NewPasswordController@create` | `password.reset` |
| POST | `reset-password` | `Auth\NewPasswordController@store` | `password.store` |

### `auth` ミドルウェアグループ

| Method | URI | Controller@Action | Route名 | 備考 |
|---|---|---|---|---|
| GET | `verify-email` | `Auth\EmailVerificationPromptController` | `verification.notice` | - |
| GET | `verify-email/{id}/{hash}` | `Auth\VerifyEmailController` | `verification.verify` | `signed`, `throttle:6,1` 追加 |
| POST | `email/verification-notification` | `Auth\EmailVerificationNotificationController@store` | `verification.send` | `throttle:6,1` 追加 |
| GET | `confirm-password` | `Auth\ConfirmablePasswordController@show` | `password.confirm` | - |
| POST | `confirm-password` | `Auth\ConfirmablePasswordController@store` | - | - |
| PUT | `password` | `Auth\PasswordController@update` | `password.update` | - |
| POST | `logout` | `Auth\AuthenticatedSessionController@destroy` | `logout` | - |

## コントローラ一覧（`app/Http/Controllers`）

| コントローラ | 役割（コードより） |
|---|---|
| `AppController` | ダッシュボード・取引フォーム画面・分析画面・設定画面のビュー表示とそれに必要な集計データの構築 |
| `TransactionController` | 取引のCRUD（`index`はJSON API実装のみ・ルート未登録）、CSVエクスポート |
| `CategoryController` | 科目（勘定科目）のCRUD。`index`/`create`/`edit`/`show`は空実装かつルート未登録 |
| `ClientController` | 取引先のCRUD。`store`/`destroy`のみ実装・ルート登録あり。`index`/`create`/`edit`/`show`/`update`は空実装（`update`はルートも未登録） |
| `PaymentMethodController` | 支払方法のCRUD。`store`/`update`/`destroy`のみ実装・ルート登録あり |
| `BudgetController` | 予算のCRUD（`index`はビュー`budgets.index`を返すがルート未登録のため到達不能）、AJAX用予算データ取得 |
| `DataExportController` | 期間指定で取引データをJSON配列として返却（フロントでExcel/CSV生成に使用） |
| `ProfileController` | プロフィール編集・更新・アカウント削除（Breeze標準） |
| `Auth/*` | Laravel Breeze標準の認証コントローラ群（ログイン・登録・パスワードリセット・メール確認） |

確認事項: `BudgetController@index` はビュー `budgets.index` を返すが、`resources/views` 配下に `budgets/index.blade.php` は存在しない（`find resources/views -iname "*budget*"` で該当なし）。このアクションへのルートは登録されていないため実行時エラーにはならないが、もしルートを追加した場合は `View not found` エラーになる。
