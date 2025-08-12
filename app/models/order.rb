class Order < ApplicationRecord
  belongs_to :user
  belongs_to :driver, class_name: 'User', optional: true
  belongs_to :assigned_store, class_name: 'Store', optional: true

  # Additional associations as specified in the plan
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items
  has_many :order_events, dependent: :destroy

  # Status enum as specified in the plan (changed 'new' to 'pending' to avoid AR conflict)
  enum :status, { pending: 0, accepted: 1, shopping: 2, delivering: 3, delivered: 4, cancelled: 5 }
  
  # Set default status for new orders
  after_initialize :set_default_status, if: :new_record?
  
  # Event tracking callbacks
  after_create :create_order_created_event
  after_update :create_status_change_event, if: :saved_change_to_status?
  after_update :create_driver_assignment_event, if: :saved_change_to_driver_id?

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

  # Order tracking and timeline methods
  def timeline_events
    order_events.for_timeline.includes(:user)
  end

  def add_event(event_type, user = nil, description = nil, data = {})
    OrderEvent.create_event!(self, event_type, user, description, data)
  end

  # Performance metrics
  def time_in_status(status_name)
    events = timeline_events.status_events
    
    start_event = events.find { |e| e.data['to_status'] == status_name || (e.event_type == 'created' && status_name == 'pending') }
    return nil unless start_event

    # Find the next status change after this one
    end_event = events.where('occurred_at > ?', start_event.occurred_at).first
    end_time = end_event&.occurred_at || (status == status_name ? Time.current : nil)
    
    return nil unless end_time
    
    ((end_time - start_event.occurred_at) / 1.minute).round(2)
  end

  def total_processing_time
    created_event = timeline_events.find { |e| e.event_type == 'created' }
    delivered_event = timeline_events.find { |e| e.event_type == 'delivered' }
    
    return nil unless created_event && delivered_event
    
    ((delivered_event.occurred_at - created_event.occurred_at) / 1.minute).round(2)
  end

  def shopping_duration
    time_in_status('shopping')
  end

  def delivery_duration
    time_in_status('delivering')
  end

  # Status transition helpers
  def last_status_change
    timeline_events.status_events.recent.first
  end

  def accepted_at
    timeline_events.find { |e| e.event_type == 'accepted' }&.occurred_at
  end

  def shopping_started_at
    timeline_events.find { |e| e.event_type == 'shopping_started' }&.occurred_at
  end

  def delivery_started_at
    timeline_events.find { |e| e.event_type == 'delivery_started' }&.occurred_at
  end

  def delivered_at
    timeline_events.find { |e| e.event_type == 'delivered' }&.occurred_at
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

  # Event tracking callback methods
  def create_order_created_event
    add_event('created', user, "Order was placed by #{user.name}")
  end

  def create_status_change_event
    old_status = saved_change_to_status[0]
    new_status = saved_change_to_status[1]
    
    # Create specific event types for major status changes
    case new_status
    when 'accepted'
      add_event('accepted', driver, "Order was accepted by driver #{driver&.name}", { from_status: old_status, to_status: new_status })
    when 'shopping'
      add_event('shopping_started', driver, "Driver #{driver&.name} started shopping", { from_status: old_status, to_status: new_status })
    when 'delivering'
      add_event('delivery_started', driver, "Driver #{driver&.name} started delivery", { from_status: old_status, to_status: new_status })
    when 'delivered'
      add_event('delivered', driver, "Order was delivered by #{driver&.name}", { from_status: old_status, to_status: new_status })
    when 'cancelled'
      add_event('cancelled', nil, "Order was cancelled", { from_status: old_status, to_status: new_status })
    else
      add_event('status_changed', nil, "Status changed from #{old_status} to #{new_status}", { from_status: old_status, to_status: new_status })
    end
  end

  def create_driver_assignment_event
    if driver_id.present? && saved_change_to_driver_id[1].present?
      add_event('assigned', nil, "Order was assigned to driver #{driver.name}", { driver_id: driver_id, driver_name: driver.name })
    end
  end
end
