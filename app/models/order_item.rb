class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product
  belongs_to :substitute_product, class_name: 'Product', optional: true

  # Status enum as specified in the plan
  enum :status, { pending: 0, found: 1, unavailable: 2, substituted: 3 }

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
end
