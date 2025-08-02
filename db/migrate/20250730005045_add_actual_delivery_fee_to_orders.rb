class AddActualDeliveryFeeToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :actual_delivery_fee, :decimal, precision: 8, scale: 2, null: true
  end
end
