# 旧 Laravel 版 → 新 Rails 版 カラム対応表

対象ダンプ: `ignore/kaikei_dump_20260711.sql`(MySQL, Laravel `kaikei` DB)
対象スキーマ: `db/schema.rb`(`kaikei_*` テーブル, version 2026_07_10_145205)

## 旧DBの全テーブル一覧

ダンプに含まれるテーブルは以下。このうち `budgets` `categories` `clients`
`payment_methods` `transactions` `users` が業務データ、残りは Laravel
フレームワークの標準テーブル(認証・キャッシュ・キュー)で移行対象外。

| テーブル | 種別 | 備考 |
|---|---|---|
| `budgets` | 業務データ | 移行対象 |
| `categories` | 業務データ | 移行対象 |
| `clients` | 業務データ | **空テーブル**(0件)。移行対象外(下記参照) |
| `payment_methods` | 業務データ | 移行対象 |
| `transactions` | 業務データ | 移行対象 |
| `users` | 業務データ | 移行対象(ただし認証方式が変わるため一部カラムのみ) |
| `cache` | フレームワーク | 移行対象外(Laravel キャッシュ、bot ログイン試行の残骸データが大量に残っている) |
| `cache_locks` | フレームワーク | 移行対象外 |
| `failed_jobs` | フレームワーク | 移行対象外 |
| `job_batches` | フレームワーク | 移行対象外 |
| `jobs` | フレームワーク | 移行対象外 |
| `migrations` | フレームワーク | 移行対象外 |
| `password_reset_tokens` | フレームワーク | 移行対象外(メール/パスワード認証を使わないため) |
| `sessions` | フレームワーク | 移行対象外 |

---

## `categories` → `kaikei_categories`

| 旧カラム | 型 | 新カラム | 型 | 備考 |
|---|---|---|---|---|
| `id` | bigint unsigned AI | `id` | integer PK | そのまま連番移行可(要: 採番衝突を避けるため INSERT 時に旧IDを保持するか要検討) |
| `name` | varchar NOT NULL | `name` | string NOT NULL | そのまま |
| `icon` | varchar NOT NULL | `icon` | string(nullable) | 旧は必須、新は任意。データは全件 `fas fa-xxx` 形式の Font Awesome クラス文字列なのでそのまま移行可 |
| `default_type` | varchar NOT NULL | `default_type` | string NOT NULL, check `IN ('income','expense')` | データは `income`/`expense` のみで一致。旧側に CHECK 制約なし(アプリ側バリデーションのみ)なので不正値が紛れていないか要確認 |
| `sort_order` | int NOT NULL | `sort_order` | integer NOT NULL default 0 | そのまま |
| `created_at` | timestamp NULL | `created_at` | datetime NOT NULL | 新は NOT NULL。旧データは全件値ありなので問題ないが、NULL行があれば要補完 |
| `deleted_at` | timestamp NULL | `deleted_at` | datetime NULL | 論理削除カラム。そのまま対応 |
| **(なし)** | — | `updated_at` | datetime NOT NULL | ⚠️ **要確認**: 旧 `categories` テーブルに `updated_at` カラムが存在しない。移行時は `created_at` と同値で埋めるなど方針を決める必要あり |
| **(なし)** | — | `user_id` | integer NOT NULL FK→users | ⚠️ **要確認**: 旧テーブルに `user_id` カラムが存在しない(全ユーザー共有のグローバルマスタだった)。新仕様ではユーザーごとに分離するため、移行時に全件をどのユーザーに割り当てるか決める必要がある。ダンプのカテゴリは投入者が単一ユーザー(`kokihiru`, users.id=2 相当)である可能性が高いが要確認 |

## `payment_methods` → `kaikei_payment_methods`

| 旧カラム | 型 | 新カラム | 型 | 備考 |
|---|---|---|---|---|
| `id` | bigint unsigned AI | `id` | integer PK | そのまま |
| `name` | varchar NOT NULL | `name` | string NOT NULL | そのまま(データ例: `現金`, `クレジットカード`, `銀行振込`) |
| `type` | varchar NOT NULL | `type` | string NOT NULL, check `IN ('income','expense')` | データは `income`/`expense` のみで一致 |
| `user_id` | bigint unsigned NOT NULL FK→users | `user_id` | integer NOT NULL FK→users | そのまま(旧から既にユーザー分離済み) |
| **(なし)** | — | `created_at` | datetime NOT NULL | ⚠️ **要確認**: 旧テーブルに `created_at`/`updated_at` が存在しない。移行時のタイムスタンプ値をどうするか決める必要あり(旧 `users.created_at` かダンプ実行日時などで代用) |
| **(なし)** | — | `updated_at` | datetime NOT NULL | 同上 |

## `budgets` → `kaikei_budgets`

| 旧カラム | 型 | 新カラム | 型 | 備考 |
|---|---|---|---|---|
| `id` | bigint unsigned AI | `id` | integer PK | そのまま |
| `user_id` | bigint unsigned NOT NULL FK→users | `user_id` | integer NOT NULL FK→users | そのまま |
| `category_id` | bigint unsigned NOT NULL FK→categories(id 参照) | `category_id` | integer NOT NULL FK→kaikei_categories(id 参照) | **ID参照**なのでマスタ突合不要。旧の外部キーは `ON DELETE CASCADE` だが新は方針不明(要確認: 予算はカテゴリ削除時にどうするか。categories は論理削除のみなので実質発火しないはずだが仕様として明記なし) |
| `amount` | int NOT NULL | `amount` | integer NOT NULL, check `>= 1` | 旧に下限チェックなし。移行前に 0 以下のデータがないか要確認 |
| `year` | year(MySQL YEAR型) | `year` | integer NOT NULL | 型変換のみ、実質そのまま |
| `month` | tinyint NOT NULL | `month` | integer NOT NULL, check `1〜12` | 旧に範囲チェックなし。移行前にデータ確認要 |
| `created_at` | timestamp NULL | `created_at` | datetime NOT NULL | ダンプの `budgets` テーブルは**データ0件**なので実質空移行 |
| `updated_at` | timestamp NULL | `updated_at` | datetime NOT NULL | 同上 |
| — | — | — | — | 新側ユニーク制約 `(user_id, category_id, year, month)` は旧にも同一制約あり、一致 |

⚠️ 補足: ダンプの `budgets` テーブルは INSERT 文があるが実データ 0 件(`LOCK/UNLOCK` の間に INSERT なし)。移行対象データ自体が存在しない。

## `clients` → 対応なし

| 旧カラム | 型 | 備考 |
|---|---|---|
| `id` | bigint unsigned AI | ⚠️ **要確認/移行不要**: `clients` テーブルはダンプ内でデータ 0 件。新仕様では取引先は `client_name` 自由テキストのみで専用マスタを持たない設計のため、テーブルごと移行対象外でよいと考えられる |
| `name` | varchar NOT NULL | 同上 |
| `user_id` | varchar NOT NULL | ⚠️ 型が `varchar` になっている(本来 users.id は bigint のはずだが文字列型で定義されている)。バグの可能性があるが、データが無いため実害なし。踏襲しない |

## `transactions` → `kaikei_transactions`

| 旧カラム | 型 | 新カラム | 型 | 備考 |
|---|---|---|---|---|
| `id` | bigint unsigned AI | `id` | integer PK | そのまま |
| `date` | date NOT NULL | `date` | date NOT NULL | そのまま |
| `amount` | int NOT NULL | `amount` | integer NOT NULL, check `>= 0` | データ確認要(マイナス値がないか) |
| `type` | varchar NOT NULL | `type` | string NOT NULL, check `IN ('income','expense')` | データは `income`/`expense` のみで一致 |
| `memo` | text NULL | `memo` | text NULL | そのまま(NULL多数、空文字なし) |
| `category_id` | bigint unsigned NOT NULL FK→categories(**id参照**) | `category_id` | integer NOT NULL FK→kaikei_categories(id参照) | **ID参照**。移行前提として `categories.id` の対応表(旧ID→新ID)が確定していれば単純な付け替えで済む。カテゴリ側で `user_id` 未設定問題(上記)が解決していないと、どのユーザーの科目に紐付くか未確定な点に注意 |
| `user_id` | bigint unsigned NOT NULL FK→users | `user_id` | integer NOT NULL FK→users | そのまま。ただし旧→新でユーザーIDが振り直される場合はマッピング要 |
| `payment_method_id` | bigint unsigned NULL FK→payment_methods(**id参照**) | `payment_method_id` | integer NULL FK→kaikei_payment_methods(id参照, on_delete: nullify) | **ID参照**。マスタ突合不要、旧ID→新IDの対応表があれば付け替えのみ |
| `client_id` | bigint unsigned NULL FK→clients(**id参照**) | 対応カラムなし | — | ⚠️ **要確認/移行不要**: 全行 `NULL`。`clients` テーブル自体が空データのため実質未使用の廃止済みカラムと判断できる。踏襲不要 |
| `client_name` | varchar NULL | `client_name` | string NULL | **名前(文字列)参照**。新仕様どおり自由テキストとしてそのまま移行可。マスタ突合不要(そもそも `clients` マスタが空で使われていないため) |
| `created_at` | timestamp NULL | `created_at` | datetime NOT NULL | データは全件値ありで問題なし |
| `updated_at` | timestamp NULL | `updated_at` | datetime NOT NULL | 同上 |

### 相手方(支払方法)・科目の参照方式まとめ

- **`category_id`**: 旧・新ともに **ID参照**(`categories.id` / `kaikei_categories.id`)。名前でのマスタ突合は不要。旧IDと新ID(移行後に採番される ID)の対応表さえ作れば機械的に付け替え可能。
- **`payment_method_id`**: 同様に **ID参照**。マスタ突合不要、旧→新IDの対応表で付け替え可能。ただし新スキーマは `on_delete: :nullify` なので、支払方法削除時に取引側が自動で NULL 化される点は旧(FK制約に ON DELETE 指定なし = デフォルト RESTRICT)と挙動が異なる。移行そのものには影響しない。
- **`client_id`**: ID参照のカラムが存在するが実データは全件 NULL・参照先マスタも空。**死んでいる列**であり移行不要。
- **`client_name`**: 自由テキスト。新仕様と完全一致するためそのまま移行。

## `users` → `users`(認証情報のみ非移行)

| 旧カラム | 型 | 新カラム | 型 | 備考 |
|---|---|---|---|---|
| `id` | bigint unsigned AI | `id` | integer PK | そのまま(要: 旧ID→新IDのマッピング表を作成し、他テーブルの `user_id` FK 付け替えに使う) |
| `name` | varchar NOT NULL | `name` | string NULL | そのまま移行可 |
| `email` | varchar NOT NULL UNIQUE | `email` | string NOT NULL | そのまま移行可 |
| `email_verified_at` | timestamp NULL | 対応なし | — | Google OAuth 認証に統一するため不要。移行対象外 |
| `password` | varchar NOT NULL(bcrypt hash) | 対応なし | — | メール/パスワード認証を廃止するため移行対象外(そのまま破棄) |
| `remember_token` | varchar NULL | 対応なし | — | 同上、移行対象外 |
| `created_at` | timestamp NULL | `created_at` | datetime NOT NULL | そのまま移行可 |
| `updated_at` | timestamp NULL | `updated_at` | datetime NOT NULL | そのまま移行可 |
| **(なし)** | — | `provider` | string NOT NULL | ⚠️ **要確認**: 新仕様は Google OAuth の `provider`(`"google_oauth2"` 等)を保持。旧データには存在しないため、移行時に手動で埋める必要あり |
| **(なし)** | — | `uid` | string NOT NULL | ⚠️ **要確認**: 同上、Google の UID が旧データには存在しない。移行時に該当ユーザーが実際に Google でログインした際の UID と手動突合が必要(メールアドレス一致で紐付けるのが現実的か) |
| **(なし)** | — | `avatar_url` | string NULL | 新規、Google プロフィールから取得。移行時は空でよい |

---

## 移行手順上の注意点まとめ(要確認事項一覧)

1. **`kaikei_categories.user_id`**: 旧マスタにユーザー分離がないため、移行時にどのユーザーへ割り当てるか要確認。
2. **`kaikei_categories.updated_at`**: 旧テーブルにカラム自体が無い。埋め方を要確認。
3. **`kaikei_payment_methods.created_at`/`updated_at`**: 旧テーブルにカラム自体が無い。埋め方を要確認。
4. **`users` の `provider`/`uid`**: 旧データに存在しないため、Google アカウントとの手動突合が必要。
5. **`transactions.client_id`**: 全件 NULL・参照先 `clients` テーブルも空データなので移行不要と判断(要最終確認)。
6. **`clients` テーブル**: データ0件のため移行対象外と判断(要最終確認)。
7. **旧→新の ID 再採番**: `users.id` / `categories.id` / `payment_methods.id` は移行時に Rails 側で採番し直される可能性が高く、`budgets`/`transactions` 側の FK 付け替え用に旧ID→新ID対応表の作成が必要。
8. **CHECK 制約の事前検証**: 旧DBには `amount >= 0`、`month BETWEEN 1 AND 12`、`default_type`/`type` の値域などのDBレベル制約が一切無い(アプリ側バリデーションのみ)。移行前に実データがこれらの制約を満たすか確認が必要(今回確認した範囲では `categories`/`payment_methods`/`transactions` の `type`・`default_type` は目視上 `income`/`expense` のみで一致、`budgets` はデータ0件)。
9. **テストデータ・bot ログイン試行の混入**: `cache` テーブルに大量の不審なメールアドレス(`testform.xyz` 等)によるログイン試行のキャッシュが残っている。移行対象外だが、旧アプリへの不正アクセス試行があった形跡として認識しておくとよい。
