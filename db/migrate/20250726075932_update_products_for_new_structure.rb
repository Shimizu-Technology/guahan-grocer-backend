class UpdateProductsForNewStructure < ActiveRecord::Migration[8.0]
  def up
    # Add unit_id to products
    add_reference :products, :unit, null: true, foreign_key: true
    
    # Create default units from existing data
    existing_units = execute("SELECT DISTINCT unit FROM products WHERE unit IS NOT NULL AND unit != ''").to_a
    
    existing_units.each do |row|
      unit_name = row['unit']
      # Create unit record
      unit_id = execute("INSERT INTO units (name, symbol, active, created_at, updated_at) VALUES ('#{unit_name}', '#{unit_name}', true, NOW(), NOW()) RETURNING id").first['id']
      
      # Update products with this unit
      execute("UPDATE products SET unit_id = #{unit_id} WHERE unit = '#{unit_name}'")
    end
    
    # Create default categories from existing data
    existing_categories = execute("SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != ''").to_a
    
    existing_categories.each do |row|
      category_name = row['category']
      # Create category record
      category_id = execute("INSERT INTO categories (name, active, created_at, updated_at) VALUES ('#{category_name}', true, NOW(), NOW()) RETURNING id").first['id']
      
      # Create product_category associations
      execute("INSERT INTO product_categories (product_id, category_id, created_at, updated_at) SELECT id, #{category_id}, NOW(), NOW() FROM products WHERE category = '#{category_name}'")
    end
    
    # Remove old columns
    remove_column :products, :category
    remove_column :products, :unit
    
    # Make unit_id required now that data is migrated
    change_column_null :products, :unit_id, false
  end
  
  def down
    # Add back old columns
    add_column :products, :category, :string
    add_column :products, :unit, :string
    
    # Migrate data back
    execute("UPDATE products SET unit = (SELECT name FROM units WHERE units.id = products.unit_id)")
    execute("UPDATE products SET category = (SELECT categories.name FROM categories JOIN product_categories ON categories.id = product_categories.category_id WHERE product_categories.product_id = products.id LIMIT 1)")
    
    # Remove new associations
    remove_reference :products, :unit, foreign_key: true
  end
end
