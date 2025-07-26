class RenameImageKeyToImageUrlInProducts < ActiveRecord::Migration[8.0]
  def change
    rename_column :products, :image_key, :image_url
  end
end
