class AddOpenFoodFactsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :gtin, :string
    add_column :products, :brand, :string
    add_column :products, :size, :string
    add_column :products, :nutrition_data, :json
    add_column :products, :image_urls, :text, array: true, default: []
    
    # Add indexes for performance
    add_index :products, :gtin, unique: true
    add_index :products, :brand
  end
end
