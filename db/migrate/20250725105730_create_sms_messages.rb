class CreateSmsMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :sms_messages do |t|
      t.string :phone
      t.text :message
      t.integer :status
      t.datetime :sent_at

      t.timestamps
    end
  end
end
