class AddWeightFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :weight_based, :boolean, default: false, null: false
    add_column :products, :price_per_unit, :decimal, precision: 10, scale: 2
    add_column :products, :weight_unit, :string, limit: 20
    add_column :products, :min_weight, :decimal, precision: 8, scale: 3
    add_column :products, :max_weight, :decimal, precision: 8, scale: 3
    
    # Add index for efficient querying of weight-based products
    add_index :products, :weight_based
  end
end
