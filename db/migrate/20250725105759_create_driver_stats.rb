class CreateDriverStats < ActiveRecord::Migration[8.0]
  def change
    create_table :driver_stats do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :total_deliveries, default: 0
      t.decimal :total_earnings, precision: 8, scale: 2, default: 0
      t.decimal :average_rating, precision: 3, scale: 2
      t.integer :total_ratings, default: 0
      t.date :date

      t.timestamps
    end
  end
end
