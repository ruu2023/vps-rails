# kaikei 取引まわりのデータモデル確認

出典: `db/schema.rb`(version: 2026_07_10_145205)、`app/models/kaikei/*.rb`。
以下は実際のスキーマ・モデル定義をそのまま書き出したもの(推測なし)。

## kaikei_transactions

`db/schema.rb`:

```ruby
create_table "kaikei_transactions", force: :cascade do |t|
  t.integer "amount", null: false
  t.integer "category_id", null: false
  t.string "client_name"
  t.datetime "created_at", null: false
  t.date "date", null: false
  t.text "memo"
  t.integer "payment_method_id"
  t.string "type", null: false
  t.datetime "updated_at", null: false
  t.integer "user_id", null: false
  t.index ["category_id"], name: "index_kaikei_transactions_on_category_id"
  t.index ["payment_method_id"], name: "index_kaikei_transactions_on_payment_method_id"
  t.index ["user_id"], name: "index_kaikei_transactions_on_user_id"
  t.check_constraint "amount >= 0", name: "kaikei_transactions_amount_check"
  t.check_constraint "type IN ('income', 'expense')", name: "kaikei_transactions_type_check"
end
```

外部キー(`db/schema.rb`末尾):

```ruby
add_foreign_key "kaikei_transactions", "kaikei_categories", column: "category_id"
add_foreign_key "kaikei_transactions", "kaikei_payment_methods", column: "payment_method_id", on_delete: :nullify
add_foreign_key "kaikei_transactions", "users"
```

**`client_name` と `payment_method_id` は両方存在する。** `client_name`(string、NULL許容)と`payment_method_id`(integer、NULL許容)が別カラムとして共存している。

モデル `app/models/kaikei/transaction.rb`:

```ruby
class Kaikei::Transaction < ApplicationRecord
  self.table_name = "kaikei_transactions"
  self.inheritance_column = nil

  TYPES = %w[income expense].freeze

  belongs_to :user
  belongs_to :category, class_name: "Kaikei::Category"
  belongs_to :payment_method, class_name: "Kaikei::PaymentMethod", optional: true

  validates :date, presence: true
  validates :amount, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :type, inclusion: { in: TYPES }

  validate :type_matches_category_default_type
  ...
end
```

- `client_name` はバリデーション対象外(モデル上に `validates :client_name` の記述なし)。
- `payment_method_id` に対応する `belongs_to :payment_method` は `optional: true`。
- `category_id` に対応する `belongs_to :category` は必須(optional指定なし)。

## kaikei_payment_methods

`db/schema.rb`:

```ruby
create_table "kaikei_payment_methods", force: :cascade do |t|
  t.datetime "created_at", null: false
  t.string "name", null: false
  t.string "type", null: false
  t.datetime "updated_at", null: false
  t.integer "user_id", null: false
  t.index ["user_id"], name: "index_kaikei_payment_methods_on_user_id"
  t.check_constraint "type IN ('income', 'expense')", name: "kaikei_payment_methods_type_check"
end
```

**収入/支出を区別する属性は存在する。名前は `type`。** 値は `'income'` / `'expense'` の2値にDBのcheck constraintで制限されている。

モデル `app/models/kaikei/payment_method.rb`:

```ruby
class Kaikei::PaymentMethod < ApplicationRecord
  self.table_name = "kaikei_payment_methods"
  self.inheritance_column = nil

  TYPES = %w[income expense].freeze

  belongs_to :user
  has_many :transactions, class_name: "Kaikei::Transaction", foreign_key: :payment_method_id, inverse_of: :payment_method

  validates :name, presence: true
  validates :type, inclusion: { in: TYPES }
end
```

- `self.inheritance_column = nil` により、`type` カラムはActiveRecordのSTI用予約カラムとして扱われず、通常の属性として使える。
- `type` に対する `belongs_to`/`has_many` などのリレーションは無い(値カラムのみ)。
- `Kaikei::Category` への参照(`belongs_to :category` 等)はモデル定義に存在しない。

## kaikei_categories(勘定科目)

`db/schema.rb`:

```ruby
create_table "kaikei_categories", force: :cascade do |t|
  t.datetime "created_at", null: false
  t.string "default_type", null: false
  t.datetime "deleted_at"
  t.string "icon"
  t.string "name", null: false
  t.integer "sort_order", default: 0, null: false
  t.datetime "updated_at", null: false
  t.integer "user_id", null: false
  t.index ["deleted_at"], name: "index_kaikei_categories_on_deleted_at"
  t.index ["user_id"], name: "index_kaikei_categories_on_user_id"
  t.check_constraint "default_type IN ('income', 'expense')", name: "kaikei_categories_default_type_check"
end
```

外部キー:

```ruby
add_foreign_key "kaikei_categories", "users"
```

モデル `app/models/kaikei/category.rb`:

```ruby
class Kaikei::Category < ApplicationRecord
  self.table_name = "kaikei_categories"

  TYPES = %w[income expense].freeze

  belongs_to :user
  has_many :transactions, class_name: "Kaikei::Transaction", foreign_key: :category_id, inverse_of: :category
  has_many :budgets, class_name: "Kaikei::Budget", foreign_key: :category_id, inverse_of: :category

  default_scope { where(deleted_at: nil) }

  validates :name, presence: true
  validates :default_type, inclusion: { in: TYPES }

  def discard
    update(deleted_at: Time.current)
  end

  def discarded?
    deleted_at.present?
  end
end
```

- `kaikei_categories` テーブルに `payment_method_id` などpayment_methodを指す外部キーカラムは存在しない。
- `Kaikei::Category` モデルに `belongs_to :payment_method` / `has_many :payment_methods` などpayment_methodとのリレーション定義は存在しない。
- **`Kaikei::Category` と `Kaikei::PaymentMethod` の間に直接のリレーションは無い。** 双方とも `user` への `belongs_to` と、`Kaikei::Transaction` からの外部キー参照(`category_id` / `payment_method_id`、それぞれ独立したカラム)を介してのみ間接的につながっている。

## リレーション関係の要約(スキーマ・モデルに基づく事実)

| テーブル/モデル | user | category | payment_method | transaction からの参照 |
|---|---|---|---|---|
| `kaikei_categories` / `Kaikei::Category` | `belongs_to :user` | — | リレーションなし | `has_many :transactions` (`category_id`) |
| `kaikei_payment_methods` / `Kaikei::PaymentMethod` | `belongs_to :user` | リレーションなし | — | `has_many :transactions` (`payment_method_id`) |
| `kaikei_transactions` / `Kaikei::Transaction` | `belongs_to :user` | `belongs_to :category`(必須) | `belongs_to :payment_method`(`optional: true`) | — |
