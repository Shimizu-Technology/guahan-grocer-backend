class Order < ApplicationRecord
  belongs_to :user
  belongs_to :driver, class_name: 'User', optional: true

  # Additional associations as specified in the plan
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  # Status enum as specified in the plan (changed 'new' to 'pending' to avoid AR conflict)
  enum :status, { pending: 0, shopping: 1, delivering: 2, delivered: 3, cancelled: 4 }

  # Validations
  validates :status, presence: true
  validates :total, presence: true, numericality: { greater_than: 0 }
  validates :delivery_address, presence: true
  validates :tip_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tip_percentage, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
