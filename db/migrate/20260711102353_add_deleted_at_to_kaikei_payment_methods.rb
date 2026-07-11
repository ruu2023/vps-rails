class AddDeletedAtToKaikeiPaymentMethods < ActiveRecord::Migration[8.1]
  def change
    add_column :kaikei_payment_methods, :deleted_at, :datetime
    add_index :kaikei_payment_methods, :deleted_at

    remove_foreign_key :kaikei_transactions, :kaikei_payment_methods
    add_foreign_key :kaikei_transactions, :kaikei_payment_methods, column: :payment_method_id
  end
end
