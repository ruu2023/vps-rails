class CreateKaikeiCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :kaikei_categories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :icon
      t.string :default_type, null: false
      t.integer :sort_order, null: false, default: 0
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :kaikei_categories, :deleted_at
    add_check_constraint :kaikei_categories, "default_type IN ('income', 'expense')", name: "kaikei_categories_default_type_check"
  end
end
