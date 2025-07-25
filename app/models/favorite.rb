class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :product

  # Prevent duplicate favorites
  validates :user_id, uniqueness: { scope: :product_id }
end
