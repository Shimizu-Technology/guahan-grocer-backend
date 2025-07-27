class CreateUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :units do |t|
      t.string :name, null: false
      t.string :symbol, null: false
      t.boolean :active, default: true

      t.timestamps
    end
    
    add_index :units, :name, unique: true
    add_index :units, :symbol, unique: true
    add_index :units, [:active, :name]
  end
end
