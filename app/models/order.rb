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

  # Additional performance metrics
  def assignment_to_acceptance_time
    assigned_event = timeline_events.find { |e| e.event_type == 'assigned' }
    accepted_event = timeline_events.find { |e| e.event_type == 'accepted' }
    
    return nil unless assigned_event && accepted_event
    
    ((accepted_event.occurred_at - assigned_event.occurred_at) / 1.minute).round(2)
  end

  def acceptance_to_shopping_time
    accepted_event = timeline_events.find { |e| e.event_type == 'accepted' }
    shopping_event = timeline_events.find { |e| e.event_type == 'shopping_started' }
    
    return nil unless accepted_event && shopping_event
    
    ((shopping_event.occurred_at - accepted_event.occurred_at) / 1.minute).round(2)
  end

  def shopping_to_delivery_time
    shopping_event = timeline_events.find { |e| e.event_type == 'shopping_completed' }
    delivery_event = timeline_events.find { |e| e.event_type == 'delivery_started' }
    
    # If no shopping_completed event, use the last shopping event
    unless shopping_event
      receipt_event = timeline_events.find { |e| e.event_type == 'receipt_uploaded' }
      shopping_event = receipt_event || timeline_events.find { |e| e.event_type == 'shopping_started' }
    end
    
    return nil unless shopping_event && delivery_event
    
    ((delivery_event.occurred_at - shopping_event.occurred_at) / 1.minute).round(2)
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

  # Route optimization and batch delivery helpers
  def self.suggested_delivery_order(orders)
    return orders if orders.count <= 1
    
    # Simple optimization: sort by distance from store (closest first)
    # More sophisticated routing algorithms can be added later
    orders.sort_by do |order|
      # Use store_distance_miles if available, otherwise treat as equal priority
      order.store_distance_miles || 999
    end
  end

  def delivery_coordinates
    return nil unless delivery_address.present?
    
    # Extract coordinates if available in delivery_address JSON
    if delivery_address.is_a?(Hash)
      lat = delivery_address['lat'] || delivery_address[:lat]
      lng = delivery_address['lng'] || delivery_address[:lng]
      return [lat.to_f, lng.to_f] if lat && lng
    end
    
    nil
  end

  def batch_info(for_driver: false)
    return nil unless driver.present?
    
    batch_orders = Order.where(
      driver: driver,
      status: ['accepted', 'shopping', 'delivering']
    ).includes(:user).order(:created_at)
    
    return nil if batch_orders.count <= 1
    
    total_earnings = batch_orders.sum(:estimated_payout)
    suggested_order = Order.suggested_delivery_order(batch_orders)
    current_index = suggested_order.index(self)
    
    {
      total_orders: batch_orders.count,
      total_earnings: total_earnings.round(2),
      current_order_index: current_index ? current_index + 1 : nil,
      other_orders: batch_orders.where.not(id: id).map do |other_order|
        {
          id: other_order.id,
          customer_name: other_order.user.name.split.first,
          status: other_order.status,
          estimated_payout: (other_order.estimated_payout || 0).round(2),
          distance: other_order.store_distance_miles&.round(1)
        }
      end,
      suggested_delivery_order: suggested_order.map.with_index do |suggested_order, index|
        {
          order_id: suggested_order.id,
          position: index + 1,
          customer_name: suggested_order.user.name.split.first,
          is_current_order: suggested_order.id == id,
          distance: suggested_order.store_distance_miles&.round(1)
        }
      end
    }
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
    
    # Check if we have admin context from controller
    status_changing_admin = instance_variable_get(:@assigning_admin)
    
    # Create specific event types for major status changes
    case new_status
    when 'accepted'
      if status_changing_admin
        # Admin forced acceptance during assignment
        add_event('accepted', status_changing_admin, nil, { 
          from_status: old_status, 
          to_status: new_status,
          driver_name: driver&.name,
          changed_by: status_changing_admin.name,
          changed_by_role: status_changing_admin.role,
          change_type: 'admin_assignment'
        })
      else
        # Driver self-accepted
        add_event('accepted', driver, nil, { 
          from_status: old_status, 
          to_status: new_status,
          driver_name: driver&.name,
          change_type: 'driver_action'
        })
      end
    when 'shopping'
      add_event('shopping_started', driver, nil, { 
        from_status: old_status, 
        to_status: new_status,
        driver_name: driver&.name,
        change_type: 'driver_action'
      })
    when 'delivering'
      add_event('delivery_started', driver, nil, { 
        from_status: old_status, 
        to_status: new_status,
        driver_name: driver&.name,
        change_type: 'driver_action'
      })
    when 'delivered'
      add_event('delivered', driver, nil, { 
        from_status: old_status, 
        to_status: new_status,
        driver_name: driver&.name,
        change_type: 'driver_action'
      })
    when 'cancelled'
      if status_changing_admin
        add_event('cancelled', status_changing_admin, nil, { 
          from_status: old_status, 
          to_status: new_status,
          changed_by: status_changing_admin.name,
          changed_by_role: status_changing_admin.role,
          change_type: 'admin_action'
        })
      else
        add_event('cancelled', nil, "Order was cancelled", { 
          from_status: old_status, 
          to_status: new_status,
          change_type: 'system'
        })
      end
    else
      add_event('status_changed', nil, "Status changed from #{old_status} to #{new_status}", { 
        from_status: old_status, 
        to_status: new_status,
        change_type: 'system'
      })
    end
  end

  def create_driver_assignment_event
    if driver_id.present? && saved_change_to_driver_id[1].present?
      # Check if we have admin context from controller
      assigning_admin = instance_variable_get(:@assigning_admin)
      
      if assigning_admin
        # Admin assignment
        add_event('assigned', assigning_admin, nil, { 
          driver_id: driver_id, 
          driver_name: driver.name,
          assigned_by: assigning_admin.name,
          assigned_by_role: assigning_admin.role,
          assignment_type: 'admin'
        })
      else
        # System or driver self-acceptance (fallback)
        add_event('assigned', nil, "Order was assigned to driver #{driver.name}", { 
          driver_id: driver_id, 
          driver_name: driver.name,
          assignment_type: 'system'
        })
      end
    end
  end
end
