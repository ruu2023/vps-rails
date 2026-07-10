# DBスキーマとリレーション

出典: `database/migrations/*.php`（マイグレーション実行順に記載）

## テーブル一覧

### `users`（`0001_01_01_000000_create_users_table.php`）
| カラム | 型 | 制約 |
|---|---|---|
| id | bigint (id) | PK |
| name | string | - |
| email | string | unique |
| email_verified_at | timestamp | nullable |
| password | string | - |
| remember_token | string | rememberToken |
| created_at / updated_at | timestamp | - |

### `password_reset_tokens` / `sessions` / `cache` / `cache_locks` / `jobs` / `job_batches` / `failed_jobs`
Laravel標準のフレームワークテーブル（認証・セッション・キャッシュ・キュー用）。業務ロジックには直接関与しない。

### `categories`（`2025_05_03_121706_create_categories_table.php` + `2025_05_24_091434_add_soft_deletes_to_categories_table.php`）
| カラム | 型 | 制約 |
|---|---|---|
| id | bigint (id) | PK |
| name | string | - |
| icon | string | nullable |
| default_type | string | コメント「income or expense」（DBレベルでのenum制約なし。バリデーションはアプリ層 `CategoryRequest` で担保） |
| sort_order | integer | default 0 |
| created_at | timestamp | nullable（`timestamps()`ではなく単一カラム追加。モデル側 `$timestamps = false` で手動管理） |
| deleted_at | timestamp | nullable（`softDeletes()`で後から追加。論理削除用） |

`user_id` カラムは存在しない ＝ 科目（カテゴリ）は全ユーザー共通のグローバルなマスタデータ（ユーザーごとに分離されていない）。

### `payment_methods`（`2025_05_03_123134_create_payment_methods_table.php`）
| カラム | 型 | 制約 |
|---|---|---|
| id | bigint (id) | PK |
| name | string | - |
| type | string | コメント「income or expense」（DBレベルでのenum制約なし） |
| user_id | foreignId | `constrained()` → `users.id` へのFK、NOT NULL |

`timestamps()` なし（モデル側 `$timestamps = false` と一致）。

### `clients`（`2025_05_03_124114_create_clients_table.php`）
| カラム | 型 | 制約 |
|---|---|---|
| id | bigint (id) | PK |
| name | string | - |
| user_id | **string** | `constrained()` |

`timestamps()` なし（モデル側 `$timestamps = false` と一致）。

**検出事項（事実）**: `user_id` カラムが `$table->string('user_id')->constrained()` と定義されている（`database/migrations/2025_05_03_124114_create_clients_table.php:14`）。他の全テーブル（`payment_methods`, `transactions`, `budgets`）では `user_id` は `$table->foreignId(...)->constrained()`（符号なし64bit整数）で定義されているのに対し、`clients` テーブルのみ型が `string` になっている。参照先の `users.id` は `bigint` であるため、型の不一致が生じている。SQLite（本プロジェクトの既定DB接続）は型アフィニティが緩いため実害が出ない可能性があるが、MySQL/PostgreSQL等の厳密な外部キー型チェックを行うDBでは、マイグレーション実行時にFK制約作成が失敗する可能性がある。
**要確認**: 実際に他DBドライバでマイグレーションを実行した際の挙動は検証していない。

### `transactions`（`2025_05_03_124115_create_transactions_table.php` + `2025_05_11_065838_add_client_name_to_transactions_table.php`）
| カラム | 型 | 制約 |
|---|---|---|
| id | bigint (id) | PK |
| date | date | - |
| amount | integer | - |
| type | string | コメント「income, or expense」（DBレベルでのenum制約なし） |
| memo | text | nullable |
| category_id | foreignId | `constrained()` → `categories.id`、NOT NULL |
| user_id | foreignId | `constrained()` → `users.id`、NOT NULL |
| payment_method_id | foreignId | nullable, `constrained()` → `payment_methods.id` |
| client_id | foreignId | nullable, `constrained()` → `clients.id` |
| client_name | string | nullable（後から追加。マイグレーションコメント「MVPように取引先名を直接指定」） |
| created_at / updated_at | timestamp | `timestamps()` |

### `budgets`（`2025_06_08_021436_create_budgets_table.php`）
| カラム | 型 | 制約 |
|---|---|---|
| id | bigint (id) | PK |
| user_id | foreignId | `constrained()->onDelete('cascade')` → `users.id` |
| category_id | foreignId | `constrained()->onDelete('cascade')` → `categories.id` |
| amount | integer | 予算金額 |
| year | year | - |
| month | tinyInteger | - |
| created_at / updated_at | timestamp | `timestamps()` |
| ユニーク制約 | `unique(['user_id', 'category_id', 'year', 'month'])` | 同一ユーザー・同一科目・同一年月の予算は1件のみ |

## ER関係図（テキスト表現）

```
users 1 ── n payment_methods   (payment_methods.user_id)
users 1 ── n clients           (clients.user_id)
users 1 ── n transactions      (transactions.user_id)
users 1 ── n budgets           (budgets.user_id, ON DELETE CASCADE)

categories 1 ── n transactions (transactions.category_id)
categories 1 ── n budgets      (budgets.category_id, ON DELETE CASCADE)
（categories はユーザー非依存の共通マスタ）

payment_methods 1 ── n transactions (transactions.payment_method_id, nullable)
clients 1 ── n transactions         (transactions.client_id, nullable)
```

## モデルとリレーション定義（`app/Models/*.php`）

| モデル | リレーションメソッド | 対応先 |
|---|---|---|
| `Transaction` | `category()`, `user()`, `paymentMethod()`, `client()` | すべて `belongsTo` |
| `Budget` | `user()`, `category()` | すべて `belongsTo` |
| `PaymentMethod` | `user()` | `belongsTo` — **ただしメソッド内で `$this->belognsTo(...)` とタイプミスがあり（`app/Models/PaymentMethod.php:18`）、実際には存在しないメソッド呼び出しとなるため、`$paymentMethod->user` へのアクセス（動的プロパティ経由のリレーション呼び出し）は `Error: Call to undefined method` で例外になる（事実：コード上の誤字）。** |
| `Category` | なし | リレーションメソッド未定義（`transactions()`, `budgets()`の逆参照は実装されていない） |
| `Client` | なし | リレーションメソッド未定義（`user()`, `transactions()`の逆参照は実装されていない） |
| `User` | なし（標準Breezeのまま） | 各モデルへの逆参照（`transactions()`, `budgets()`等）は未実装 |

**要確認**: `PaymentMethod::user()` のタイプミスは現在の使用箇所（`AppController`, `BudgetController`, `TransactionController` 等）で `paymentMethod->user` が呼び出されていないため、実害が顕在化していない可能性がある。将来的にこのリレーションを使用するコードが追加された場合にのみ実行時エラーとなる。
