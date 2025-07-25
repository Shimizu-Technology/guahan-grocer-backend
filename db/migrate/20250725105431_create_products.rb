class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.string :category
      t.decimal :price, precision: 8, scale: 2
      t.string :unit
      t.text :description
      t.boolean :in_stock, default: true
      t.integer :stock_quantity, default: 0
      t.string :image_key

      t.timestamps
    end
  end
end
