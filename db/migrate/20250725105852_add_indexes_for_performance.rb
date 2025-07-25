class AddIndexesForPerformance < ActiveRecord::Migration[8.0]
  def change
    # User indexes for authentication and role queries
    add_index :users, [:email], unique: true
    add_index :users, [:role, :active]
    
    # Product indexes for catalog browsing and inventory
    add_index :products, [:category, :in_stock]
    add_index :products, [:stock_quantity], where: "stock_quantity <= 10"
    
    # Order indexes for user history and driver assignment
    add_index :orders, [:user_id, :status, :created_at]
    add_index :orders, [:driver_id, :status], where: "driver_id IS NOT NULL"
    
    # Order item indexes for order details (product_id already exists from references)
    add_index :order_items, [:order_id, :status]
    # Note: product_id index already created by Rails with 'references'
    
    # Favorites indexes for user wishlist uniqueness
    add_index :favorites, [:user_id, :product_id], unique: true
    
    # Driver stats indexes for analytics and uniqueness
    add_index :driver_stats, [:user_id, :date], unique: true
  end
end
