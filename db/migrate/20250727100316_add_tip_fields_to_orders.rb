class AddTipFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :tip_amount, :decimal, precision: 8, scale: 2, default: 0.00, null: false
    add_column :orders, :tip_percentage, :decimal, precision: 5, scale: 2, default: 0.00, null: false
    
    add_index :orders, :tip_amount
  end
end
