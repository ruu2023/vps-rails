# モデルごとのビジネスルール

出典: `app/Models/*.php`, `app/Http/Controllers/*.php`, `app/Http/Requests/*.php`, `app/Policies/*.php`

> 総論（事実）: リポジトリ全体を `round|floor|ceil|tax|税|端数` で検索した結果、消費税計算ロジックは一切存在しない。金額計算で小数を扱う箇所は「前月比・進捗率のパーセンテージ表示」のみであり、取引金額そのものは常に整数（円）として扱われる。端数処理（丸め）が行われる箇所は本ドキュメント内で個別に明記する。

## Transaction（取引）

**ソース**: `app/Models/Transaction.php`, `app/Http/Controllers/TransactionController.php`, `app/Policies/TransactionPolicy.php`

- `fillable`: `date, amount, type, memo, category_id, user_id, payment_method_id, client_id, client_name`
- カラム型による暗黙のキャスト: `amount` はDB上 `integer`（マイグレーション定義）。モデル側に `$casts` の明示定義はない。
- リレーション: `category()`, `user()`, `paymentMethod()`, `client()`（すべて `belongsTo`）

### バリデーション（`store`/`update` 共通、コントローラ内インラインルール）
```
date              => required|date
amount            => required|integer|min:0
type              => required|in:income,expense
memo              => nullable|string
category_id       => required|exists:categories,id
payment_method_id => nullable|exists:payment_methods,id
client_id         => nullable|exists:clients,id
client_name       => nullable|string|max:255
```
- `amount` は `min:0` のため **0円の取引も許可される**（負数は不可）。上限値のバリデーションは無い。
- `store()` では `user_id` をバリデーション後に `Auth::id()` で強制上書き（クライアントから偽装不可）。
- `update()` も同一のバリデーションルールを再適用するが、`user_id` の再設定は行われない（既存レコードの`user_id`のまま）。

### 金額計算・集計ロジック
- 金額計算に消費税・端数処理は一切登場しない。すべて `sum('amount')` による単純合計。
- 収支バランス = `収入合計 - 支出合計`（`AppController@dashboard` L34, `AppController@analytics` L161 など）。四則演算のみで丸め処理なし。
- 前月比・期間比較の変化率:
  ```
  変化率(%) = 前月値 > 0 ? ((今月値 - 前月値) / 前月値) * 100 : 0
  ```
  （`AppController@dashboard` L52-57）。**丸め処理はコントローラ側では行わず**、Blade側で表示直前に `number_format($balanceChange, 1)`（小数第1位、PHPの`number_format`は四捨五入＝正確には「0.5は偶数丸めでなく通常の四捨五入」相当の丸め処理。`resources/views/pages/dashboard.blade.php:456`）を適用しているのみ。`incomeChange`/`expenseChange`は本調査で確認した範囲ではBlade側の丸め表示箇所を特定していない。**要確認**: `incomeChange`, `expenseChange` がダッシュボード画面上で表示されているか、また表示時の丸め有無は未確認。
- 残高がマイナスの場合の変化率計算は `abs($previousMonthBalance)` で除算（ゼロ除算・符号反転考慮のためだが、`previousMonthBalance = 0` の場合は変化率を`0`とする分岐がある一方、`currentMonthBalance`側の扱いに特別な分岐はない）。

### 権限制御（`TransactionPolicy`）
- `view`, `update`, `delete`: `$user->id === $transaction->user_id` の場合のみ許可。
- `viewAny`, `create`: 常に `false`（未使用のポリシーメソッドで、`store()`では呼ばれていないため実質無効。**事実**: `store()`アクションに `$this->authorize()` 呼び出しは存在しない＝作成時のポリシー適用はコード上ない）。
- `show`, `edit`, `update`, `destroy` の各コントローラアクションでは明示的に `$this->authorize(...)` を呼び出しており、他ユーザーの取引に対する閲覧・更新・削除は `403` で拒否される。

### CSVエクスポート（`exportCsv`）
- 追加バリデーション: `start_date => required|date`, `end_date => required|date|after_or_equal:start_date`
- 出力は「仕訳帳」形式（借方・貸方）。
  - `type === 'income'`（収入）: 借方＝支払方法名（`現金`がデフォルト）／借方金額＝取引金額、貸方＝科目名／貸方金額は空欄
  - それ以外（支出）: 借方＝科目名／借方金額＝取引金額、貸方＝支払方法名（`現金`がデフォルト）／貸方金額は空欄
  - 金額の按分・複数行仕訳・消費税抜き出しといった簿記上の税抜計算は行われていない（取引金額をそのまま借方・貸方いずれかに転記するのみ）。
- 文字コード: UTF-8 BOM付き（Excelでの文字化け対策、コメントに明記）。

## Category（科目）

**ソース**: `app/Models/Category.php`, `app/Http/Controllers/CategoryController.php`, `app/Http/Requests/CategoryRequest.php`

- `fillable`: `name, icon, default_type, sort_order, created_at`
- `SoftDeletes` 使用（論理削除、`deleted_at`）
- `$timestamps = false`（コメント「created_atは手動」）— `updated_at` カラム自体がDBに存在しない。

### バリデーション（`CategoryRequest`）
```
name         => required|string|max:255
icon         => nullable|string|max:255
default_type => required|in:income,expense
sort_order   => nullable|integer
```
- `CategoryRequest::authorize()` は常に `true`（＝認可チェックなし。ログイン済みユーザーなら誰でも作成・更新可能）。

### 業務ロジック
- 新規作成時、`sort_order` はリクエスト値を使わず **サーバー側で常に上書き**: `Category::max('sort_order') + 1`（`CategoryController@store` L37-38）。リクエストの `sort_order` バリデーションルールは存在するが、`store()`では実質使用されない（`update()`では上書きされずリクエスト値がそのまま反映される）。
- `default_type` は勘定科目の既定収支区分（`income`/`expense`）。DBに列挙型制約は無く、アプリ層バリデーションのみで担保。
- 科目は**ユーザーに紐付かないグローバルなマスタ**（`categories`テーブルに`user_id`なし）。そのため、あるユーザーが作成・編集・削除した科目は全ユーザーに影響する。
- **検出事項（事実）**: `update`/`destroy` アクションには所有者チェック・ポリシー適用が一切ない（`Category`用の`Policy`クラス自体が存在しない）。設計上科目が全ユーザー共通である前提と一致するため、これは意図した挙動である可能性が高い（**要確認**: 複数ユーザーが同一科目マスタを共有する仕様として意図されているか、本来はユーザーごとに分離されるべきなのかは、コードのみからは断定できない）。

## PaymentMethod（支払方法）

**ソース**: `app/Models/PaymentMethod.php`, `app/Http/Controllers/PaymentMethodController.php`

- `fillable`: `name, type, user_id`
- `$timestamps = false`
- `user()`: `belongsTo(User::class)` の**呼び出しに誤字あり**（`$this->belognsTo(...)`、`app/Models/PaymentMethod.php:18`）。呼び出せば実行時エラー（詳細は[02_db_schema.md](02_db_schema.md)参照）。

### バリデーション（`store`/`update` 共通）
```
name => required|string|max:255
type => required|in:income,expense
```
- `store()`時、`user_id`はリクエスト後に`Auth::id()`で強制設定。
- **検出事項（事実）**: `update()`/`destroy()`は`$this`のオーナーシップチェック（`Auth::id() === $paymentMethod->user_id`等の比較や`$this->authorize()`呼び出し）を一切行っていない。`PaymentMethod`用の`Policy`クラスも存在しない。したがって、ログイン済みの任意のユーザーが他ユーザーの支払方法のIDを指定して更新・削除するリクエストを送信した場合、成功してしまう（認可漏れ）。

## Client（取引先）

**ソース**: `app/Models/Client.php`, `app/Http/Controllers/ClientController.php`

- `fillable`: `name, user_id`
- `$timestamps = false`
- リレーションメソッド未定義（`user()`等は実装なし）

### バリデーション（`store`）
```
name => required|string|max:255
```
- `store()`時、`user_id`はリクエスト後に`Auth::id()`で強制設定。
- `update()`アクションはルート未登録かつ中身も空実装。
- **検出事項（事実）**: `destroy()`にオーナーシップチェックがない（`PaymentMethod`と同様の認可漏れ）。`Client`用の`Policy`クラスも存在しない。
- **検出事項（事実）**: 取引登録・編集フォーム（`resources/views/pages/transaction.blade.php`, `resources/views/pages/analytics.blade.php`）はいずれも `client_name`（自由テキスト）の入力欄のみを持ち、`client_id`（`clients`テーブルとの紐付け）を選択・送信するUI要素は存在しない。したがって`ClientController@store`・`clients`テーブル・`transactions.client_id`の一連の機能は、現在のUIからは到達する導線がない（**要確認**: API直叩きや将来のUI追加を前提とした未接続機能である可能性）。

## Budget（予算）

**ソース**: `app/Models/Budget.php`, `app/Http/Controllers/BudgetController.php`, `app/Policies/BudgetPolicy.php`

- `fillable`: `user_id, category_id, amount, year, month`
- `$casts`: `amount => integer`, `year => integer`, `month => integer`（明示キャストあり）
- リレーション: `user()`, `category()`（`belongsTo`）

### バリデーション（`store`）
```
category_id => required|exists:categories,id
amount      => required|integer|min:1
year        => required|integer|min:2020|max:2030
month       => required|integer|min:1|max:12
```
- `amount`は**1以上**（`min:1`。Transactionの`min:0`と異なり0円予算は不可）。
- `year`は2020〜2030年に限定（ハードコード。2031年以降は`store()`が422バリデーションエラーになる）。
- 同一ユーザー・同一科目・同一年月の予算は`Budget::updateOrCreate()`により**作成ではなく更新**として扱われる（DBのユニーク制約`unique(['user_id','category_id','year','month'])`と整合）。

### `update`（既存予算の金額変更のみ）
```
amount => required|integer|min:1
```
- `category_id`, `year`, `month`は更新不可（`amount`のみ）。

### 計算ロジック（`app/Models/Budget.php`のアクセサ）
| アクセサ | 計算式 | 端数処理 |
|---|---|---|
| `actual_spent` | 同一`user_id`・同一`category_id`・`type='expense'`・同一年月の`Transaction.amount`合計（`sum('amount')`） | なし（整数の合計のため小数は発生しない） |
| `progress_percentage` | `amount > 0 ? min((spent / amount) * 100, 100) : 0` | **丸め処理なし**（浮動小数点の生値。例: 実支出33,333円・予算100,000円なら`33.333...`という無限小数に近い値がそのままJSON/Blade側へ渡る） |
| `remaining_amount` | `max(amount - actual_spent, 0)` | なし（整数演算） |
| `is_over_budget` | `actual_spent > amount` | 真偽値 |
| `warning_level` | `progress_percentage >= 100 ? 'danger' : (progress_percentage >= 80 ? 'warning' : 'normal')` | 上記`progress_percentage`の生値をそのまま閾値比較 |

- `progress_percentage`は`min(...,100)`で**上限100に丸める（クリップする）**が、小数点以下の丸め（`round()`等）は一切行われていない。表示側（`settings.js` L340, `dashboard.blade.php`のインラインスタイル`width`指定など）でもJavaScript側の丸め処理は確認できず、CSSの`width`プロパティに生の浮動小数点値がそのまま渡る（見た目には影響しないが、値としては非整数）。
- **検出事項（事実・機能不整合）**: `resources/js/settings.js`の予算作成フォーム送信処理（L613-642）は`fetch('/budgets', {method:'POST', ...})`の応答を`response.json()`としてパースし、`data.success`を判定する実装になっている。しかし`BudgetController@store`は`back()->with('success', '予算を設定しました。')`という**302リダイレクトレスポンス**を返しており、JSON（`{success: true}`等）を返していない。同様に`deleteBudget()`（settings.js L415-437）も`DELETE /budgets/{id}`の応答を`response.json()`でパースしようとするが、`BudgetController@destroy`も`back()->with(...)`のリダイレクトを返す。**そのため、設定画面の予算追加・削除のAJAXフローは、`fetch`が`.json()`のパースに失敗する（あるいはリダイレクト先HTMLをJSONとしてパースしようとして例外になる）ため、実際には正しく動作しない可能性が高い**（要確認: ブラウザの`fetch`はリダイレクトを自動追従するため、最終的に`/settings`等のHTMLページ本文が返り、`response.json()`が`SyntaxError`で失敗する、という具体的な失敗モードは実機検証していない静的解析上の推定）。
- `editBudget()`（settings.js L407-410）はコンソールログ出力のみで**未実装**（コメントに「実装は省略」と明記）。

### 権限制御（`BudgetPolicy`）
- `viewAny`, `create`: 常に`true`
- `view`, `update`, `delete`: `$user->id === $budget->user_id`
- `update()`/`destroy()`コントローラアクションは`$this->authorize(...)`を呼んでおり、他ユーザーの予算は編集・削除できない。

## User（利用者）

**ソース**: `app/Models/User.php`, `app/Http/Requests/ProfileUpdateRequest.php`, `app/Http/Controllers/ProfileController.php`

- Laravel Breeze標準の`User`モデル。`fillable`: `name, email, password`。`hidden`: `password, remember_token`。`password`は`hashed`キャスト（自動ハッシュ化）。
- プロフィール更新バリデーション（`ProfileUpdateRequest`）:
  ```
  name  => required|string|max:255
  email => required|string|lowercase|email|max:255|unique(users, ignore: 自分自身)
  ```
  - メールアドレス変更時は`email_verified_at`を`null`にリセット（再確認要求、`ProfileController@update` L31-33）。
- アカウント削除（`ProfileController@destroy`）: `current_password`ルールで**現在のパスワード再入力必須**。削除後にログアウト・セッション再生成を実施。
