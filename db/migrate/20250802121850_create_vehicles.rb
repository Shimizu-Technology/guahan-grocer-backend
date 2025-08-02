class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :make, null: false
      t.string :model, null: false
      t.integer :year, null: false
      t.string :color, null: false
      t.string :license_plate, null: false
      t.string :vehicle_type, null: false
      t.integer :verification_status, default: 0, null: false
      t.boolean :is_primary, default: false, null: false

      t.timestamps
    end
    
    # Add indexes for performance (user_id index is created automatically by references)
    add_index :vehicles, :license_plate, unique: true
    add_index :vehicles, [:user_id, :is_primary]
    add_index :vehicles, :verification_status
  end
end
