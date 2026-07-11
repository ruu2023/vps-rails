# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_10_145205) do
  create_table "kaikei_budgets", force: :cascade do |t|
    t.integer "amount", null: false
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.integer "month", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "year", null: false
    t.index ["category_id"], name: "index_kaikei_budgets_on_category_id"
    t.index ["user_id", "category_id", "year", "month"], name: "index_kaikei_budgets_on_user_category_year_month", unique: true
    t.index ["user_id"], name: "index_kaikei_budgets_on_user_id"
    t.check_constraint "amount >= 1", name: "kaikei_budgets_amount_check"
    t.check_constraint "month BETWEEN 1 AND 12", name: "kaikei_budgets_month_check"
  end

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

  create_table "kaikei_payment_methods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_kaikei_payment_methods_on_user_id"
    t.check_constraint "type IN ('income', 'expense')", name: "kaikei_payment_methods_type_check"
  end

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

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "kaikei_budgets", "kaikei_categories", column: "category_id"
  add_foreign_key "kaikei_budgets", "users"
  add_foreign_key "kaikei_categories", "users"
  add_foreign_key "kaikei_payment_methods", "users"
  add_foreign_key "kaikei_transactions", "kaikei_categories", column: "category_id"
  add_foreign_key "kaikei_transactions", "kaikei_payment_methods", column: "payment_method_id", on_delete: :nullify
  add_foreign_key "kaikei_transactions", "users"
end
