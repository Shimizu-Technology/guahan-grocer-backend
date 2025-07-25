class DriverStat < ApplicationRecord
  belongs_to :user

  # Validations
  validates :user_id, uniqueness: { scope: :date }
  validates :total_deliveries, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_earnings, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_ratings, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :average_rating, numericality: { in: 1.0..5.0 }, allow_nil: true
  validates :date, presence: true
end
