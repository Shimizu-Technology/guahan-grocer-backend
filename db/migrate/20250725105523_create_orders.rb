class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :driver, null: true, foreign_key: { to_table: :users }
      t.integer :status
      t.decimal :total, precision: 8, scale: 2
      t.jsonb :delivery_address
      t.integer :eta
      t.decimal :estimated_payout, precision: 8, scale: 2

      t.timestamps
    end
  end
end
