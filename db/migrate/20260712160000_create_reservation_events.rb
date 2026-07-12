class CreateReservationEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :reservation_events do |t|
      t.string :title
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :has_end_time, null: false, default: false
      t.text :content
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
