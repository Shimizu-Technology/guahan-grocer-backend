class DriverStat < ApplicationRecord
  belongs_to :user

  # Validations
  validates :user_id, uniqueness: { scope: :date }
  validates :total_deliveries, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_earnings, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_ratings, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :average_rating, numericality: { in: 1.0..5.0 }, allow_nil: true
  validates :date, presence: true
  
  # New validations for enhanced fields
  validates :tips, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :base_pay, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :bonuses, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :expenses, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :hours_online, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :orders_offered, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :orders_accepted, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Helper methods
  def acceptance_rate
    return 0 if orders_offered == 0
    ((orders_accepted.to_f / orders_offered) * 100).round(1)
  end

  def orders_per_hour
    return 0 if hours_online == 0
    (total_deliveries.to_f / hours_online).round(1)
  end

  def hourly_rate
    return 0 if hours_online == 0
    (total_earnings / hours_online).round(2)
  end

  def net_earnings
    total_earnings - expenses
  end
end
