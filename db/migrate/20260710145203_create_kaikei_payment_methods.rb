class CreateKaikeiPaymentMethods < ActiveRecord::Migration[8.1]
  def change
    create_table :kaikei_payment_methods do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :type, null: false

      t.timestamps
    end

    add_check_constraint :kaikei_payment_methods, "type IN ('income', 'expense')", name: "kaikei_payment_methods_type_check"
  end
end
