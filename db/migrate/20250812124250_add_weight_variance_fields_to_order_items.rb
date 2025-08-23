class AddWeightVarianceFieldsToOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :order_items, :estimated_weight, :decimal, precision: 8, scale: 3
    add_column :order_items, :actual_weight, :decimal, precision: 8, scale: 3
    add_column :order_items, :estimated_price, :decimal, precision: 10, scale: 2
    add_column :order_items, :actual_price, :decimal, precision: 10, scale: 2
    add_column :order_items, :variance_percentage, :decimal, precision: 5, scale: 2
    add_column :order_items, :variance_approved, :boolean
    add_column :order_items, :variance_approval_method, :string, limit: 50
    add_column :order_items, :substitution_reason, :text
    add_column :order_items, :weight_verified_at, :timestamp
    
    # Add indexes for efficient querying
    add_index :order_items, :variance_approved
    add_index :order_items, :weight_verified_at
  end
end
