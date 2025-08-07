class Order < ApplicationRecord
  belongs_to :user
  belongs_to :driver, class_name: 'User', optional: true
  belongs_to :assigned_store, class_name: 'Store', optional: true

  # Additional associations as specified in the plan
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  # Status enum as specified in the plan (changed 'new' to 'pending' to avoid AR conflict)
  enum :status, { pending: 0, accepted: 1, shopping: 2, delivering: 3, delivered: 4, cancelled: 5 }
  
  # Set default status for new orders
  after_initialize :set_default_status, if: :new_record?
  
  # SMS notification callbacks
  after_create :send_order_confirmation_sms
  after_update :send_status_change_sms, if: :saved_change_to_status?

  # Validations
  validates :status, presence: true
  validates :total, presence: true, numericality: { greater_than: 0 }
  validates :subtotal, presence: true, numericality: { greater_than: 0 }
  validates :delivery_fee, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :actual_delivery_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :delivery_address, presence: true
  validates :tip_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :tip_percentage, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :delivery_time, presence: true
  
  # Validate that total matches the sum of its parts
  validate :total_matches_breakdown
  
  # Helper methods for delivery fee analysis
  def delivery_fee_variance
    return 0 unless actual_delivery_fee.present?
    actual_delivery_fee - delivery_fee
  end
  
  def delivery_fee_variance_percentage
    return 0 unless actual_delivery_fee.present? && delivery_fee > 0
    ((actual_delivery_fee - delivery_fee) / delivery_fee * 100).round(2)
  end

  private

  def set_default_status
    self.status ||= 'pending'
  end
  
  def total_matches_breakdown
    return unless subtotal.present? && delivery_fee.present? && tip_amount.present? && total.present?
    
    expected_total = subtotal + delivery_fee + tip_amount
    tolerance = 0.01 # Allow 1 cent difference for rounding
    
    unless (total - expected_total).abs <= tolerance
      errors.add(:total, "must equal subtotal + delivery fee + tip (#{expected_total.round(2)} expected, got #{total})")
    end
  end
  
  # SMS notification callback methods
  def send_order_confirmation_sms
    # Send confirmation SMS when order is created
    SendOrderConfirmationJob.perform_later(id)
  end
  
  def send_status_change_sms
    case status
    when 'accepted'
      # Driver accepted the order
      SendDriverAssignedJob.perform_later(id)
    when 'delivering'
      # Order is out for delivery
      SendOutForDeliveryJob.perform_later(id)
    when 'delivered'
      # Order has been delivered
      SendDeliveryCompleteJob.perform_later(id)
    end
  end
end
