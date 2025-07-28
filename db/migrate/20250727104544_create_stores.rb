class CreateStores < ActiveRecord::Migration[8.0]
  def change
    create_table :stores do |t|
      t.string :name, null: false
      t.text :address, null: false
      t.string :phone
      t.decimal :latitude, precision: 10, scale: 6, null: false
      t.decimal :longitude, precision: 10, scale: 6, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    add_index :stores, :active
    add_index :stores, [:latitude, :longitude]
    add_index :stores, :name
  end
end
