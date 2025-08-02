class AddOrderPerformanceOptimizations < ActiveRecord::Migration[8.0]
  def change
    # Add index for order creation timestamp lookups
    add_index :orders, :created_at, comment: "For order history and analytics queries"
    
    # Add composite index for status and created_at for efficient order filtering
    add_index :orders, [:status, :created_at], comment: "For filtering orders by status with time ordering"
    
    # Skip tip_amount index - it already exists
    
    # Add index on order_items for efficient product lookups within orders
    add_index :order_items, [:product_id, :order_id], comment: "For product-order joins"
    
    # Add index for store assignment queries (skip if assigned_store_id index already exists)
    unless index_exists?(:orders, [:assigned_store_id, :status])
      add_index :orders, [:assigned_store_id, :status], comment: "For store-specific order management"
    end
    
    # Enable better statistics collection for query planning
    execute <<-SQL
      -- Update statistics for better query planning
      ANALYZE orders;
      ANALYZE order_items;
      ANALYZE products;
    SQL
  end
  
  def down
    remove_index :orders, :created_at if index_exists?(:orders, :created_at)
    remove_index :orders, [:status, :created_at] if index_exists?(:orders, [:status, :created_at])
    remove_index :order_items, [:product_id, :order_id] if index_exists?(:order_items, [:product_id, :order_id])
    remove_index :orders, [:assigned_store_id, :status] if index_exists?(:orders, [:assigned_store_id, :status])
  end
end
