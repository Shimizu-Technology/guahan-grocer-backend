class AddWeightBasedToOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :order_items, :weight_based, :boolean
  end
end
