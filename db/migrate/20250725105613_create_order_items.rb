class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity
      t.decimal :price, precision: 8, scale: 2
      t.integer :status, default: 0
      t.integer :found_quantity
      t.text :notes
      t.references :substitute_product, null: true, foreign_key: { to_table: :products }

      t.timestamps
    end
  end
end
