class WeightVarianceApproval < ApplicationRecord
  belongs_to :order_item
  
  # Approval status enum
  enum :approval_status, {
    pending: 'pending',
    approved: 'approved',
    rejected: 'rejected',
    timeout: 'timeout'
  }
  
  # Approval method enum
  enum :approval_method, {
    auto: 'auto',
    manual: 'manual',
    timeout_auto: 'timeout_auto'
  }
  
  # Validations
  validates :original_weight, presence: true, numericality: { greater_than: 0 }
  validates :new_weight, presence: true, numericality: { greater_than: 0 }
  validates :original_price, presence: true, numericality: { greater_than: 0 }
  validates :new_price, presence: true, numericality: { greater_than: 0 }
  validates :variance_percentage, presence: true, numericality: true
  validates :approval_status, presence: true
  
  # Scopes
  scope :pending_approval, -> { where(approval_status: 'pending') }
  scope :timed_out, -> { where('timeout_at < ?', Time.current) }
  scope :for_order, ->(order_id) { 
    joins(:order_item).where(order_items: { order_id: order_id }) 
  }
  
  # Class methods
  def self.create_approval!(order_item, original_weight, new_weight, driver_note = nil)
    original_price = calculate_price(order_item, original_weight)
    new_price = calculate_price(order_item, new_weight)
    variance_percentage = calculate_variance_percentage(original_weight, new_weight)
    
    timeout_minutes = order_item.order.user.approval_timeout_minutes
    timeout_at = Time.current + timeout_minutes.minutes
    
    create!(
      order_item: order_item,
      original_weight: original_weight,
      new_weight: new_weight,
      original_price: original_price,
      new_price: new_price,
      variance_percentage: variance_percentage,
      timeout_at: timeout_at,
      driver_note: driver_note
    )
  end
  
  # Instance methods
  def approve!(method = 'manual')
    update!(
      approval_status: 'approved',
      approval_method: method,
      customer_response_at: Time.current
    )
  end
  
  def reject!(method = 'manual')
    update!(
      approval_status: 'rejected',
      approval_method: method,
      customer_response_at: Time.current
    )
  end
  
  def timeout!
    update!(
      approval_status: 'timeout',
      approval_method: 'timeout_auto',
      customer_response_at: Time.current
    )
    
    # Create timeout event
    order.add_event('variance_timeout', nil, nil, {
      item_id: order_item.id,
      item_name: order_item.product.name,
      variance_percentage: "#{variance_percentage > 0 ? '+' : ''}#{variance_percentage.round(1)}",
      estimated_weight: original_weight,
      actual_weight: new_weight,
      weight_unit: order_item.product.weight_unit,
      estimated_price: original_price,
      actual_price: new_price,
      price_difference: price_difference,
      timeout_minutes: (Time.current - (timeout_at - customer.approval_timeout_minutes.minutes)) / 60
    })
    
    # Send timeout notification
    NotificationService.send_variance_timeout_notification(order_item)
  end
  
  def price_difference
    new_price - original_price
  end
  
  def weight_difference
    new_weight - original_weight
  end
  
  def timed_out?
    timeout_at && timeout_at < Time.current
  end
  
  def customer
    order_item.order.user
  end
  
  def order
    order_item.order
  end
  
  private
  
  def self.calculate_price(order_item, weight)
    product = order_item.product
    return order_item.price unless product.weight_based?
    
    (product.price_per_unit * weight).round(2)
  end
  
  def self.calculate_variance_percentage(original_weight, new_weight)
    return 0 if original_weight == 0
    
    ((new_weight - original_weight) / original_weight * 100).round(2)
  end
end
