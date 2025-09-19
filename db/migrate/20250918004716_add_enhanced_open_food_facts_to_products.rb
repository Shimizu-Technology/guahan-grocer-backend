class AddEnhancedOpenFoodFactsToProducts < ActiveRecord::Migration[8.0]
  def change
    # Core product info (all nullable for non-food items)
    add_column :products, :serving_size, :string
    add_column :products, :ingredients_text, :text
    
    # Safety info (critical for food products, null for others)
    add_column :products, :allergens, :string
    add_column :products, :traces, :string
    
    # Classification (separate from our store categories)
    add_column :products, :off_categories, :text
    add_column :products, :off_labels, :text
    
    # Health scores (food products only)
    add_column :products, :nutriscore_grade, :string, limit: 1
    add_column :products, :nova_group, :integer
    
    # Additional images (all optional)
    add_column :products, :image_ingredients_url, :string
    add_column :products, :image_nutrition_url, :string
    
    # Environmental info (optional)
    add_column :products, :packaging, :string
    
    # Indexes for common searches (only on non-null values)
    add_index :products, :allergens, where: "allergens IS NOT NULL"
    add_index :products, :nutriscore_grade, where: "nutriscore_grade IS NOT NULL"
    add_index :products, :nova_group, where: "nova_group IS NOT NULL"
    
    # Simple indexes for filtering (can upgrade to GIN later if needed)
    add_index :products, :off_categories, where: "off_categories IS NOT NULL"
    add_index :products, :off_labels, where: "off_labels IS NOT NULL"
  end
end