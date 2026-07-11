class CreateKaikeiBudgets < ActiveRecord::Migration[8.1]
  def change
    create_table :kaikei_budgets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: { to_table: :kaikei_categories }
      t.integer :amount, null: false
      t.integer :year, null: false
      t.integer :month, null: false

      t.timestamps
    end

    add_index :kaikei_budgets, [ :user_id, :category_id, :year, :month ], unique: true, name: "index_kaikei_budgets_on_user_category_year_month"
    add_check_constraint :kaikei_budgets, "amount >= 1", name: "kaikei_budgets_amount_check"
    add_check_constraint :kaikei_budgets, "month BETWEEN 1 AND 12", name: "kaikei_budgets_month_check"
  end
end
