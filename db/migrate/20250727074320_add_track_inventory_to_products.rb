class AddTrackInventoryToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :track_inventory, :boolean, default: true, null: false
    add_index :products, :track_inventory
  end
end
