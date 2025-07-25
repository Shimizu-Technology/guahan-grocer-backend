class Product < ApplicationRecord
  # Associations as specified in the plan
  has_many :order_items, dependent: :destroy
  has_many :favorites, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :category, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :unit, presence: true
  validates :stock_quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
