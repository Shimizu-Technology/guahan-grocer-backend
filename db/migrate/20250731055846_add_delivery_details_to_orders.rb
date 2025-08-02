class AddDeliveryDetailsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :assigned_store_id, :bigint
    add_column :orders, :store_distance_miles, :decimal, precision: 8, scale: 2
    add_column :orders, :store_name, :string
    add_column :orders, :estimated_delivery_minutes, :integer
    
    # Add foreign key constraint
    add_foreign_key :orders, :stores, column: :assigned_store_id
    
    # Add index for performance
    add_index :orders, :assigned_store_id
  end
end
