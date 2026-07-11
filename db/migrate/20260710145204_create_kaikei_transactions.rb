class CreateKaikeiTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :kaikei_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: { to_table: :kaikei_categories }
      t.references :payment_method, foreign_key: { to_table: :kaikei_payment_methods, on_delete: :nullify }, index: true
      t.date :date, null: false
      t.integer :amount, null: false
      t.string :type, null: false
      t.string :client_name
      t.text :memo

      t.timestamps
    end

    add_check_constraint :kaikei_transactions, "amount >= 0", name: "kaikei_transactions_amount_check"
    add_check_constraint :kaikei_transactions, "type IN ('income', 'expense')", name: "kaikei_transactions_type_check"
  end
end
