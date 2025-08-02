class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :label, limit: 50
      t.string :street_address, null: false, limit: 255
      t.string :apartment_unit, limit: 50
      t.string :city, null: false, limit: 100
      t.string :state, null: false, limit: 10
      t.string :zip_code, null: false, limit: 20
      t.boolean :is_default, default: false, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6

      t.timestamps
    end
    
    # Indexes for performance (user_id index already created by references)
    add_index :addresses, [:user_id, :is_default]
    add_index :addresses, [:latitude, :longitude]
  end
end
