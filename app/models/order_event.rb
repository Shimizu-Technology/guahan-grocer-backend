class OrderEvent < ApplicationRecord
  belongs_to :order
  belongs_to :user, optional: true  # System events might not have a user

  # Event types enum for better validation and querying
  enum :event_type, {
    created: 'created',
    assigned: 'assigned',
    accepted: 'accepted',
    shopping_started: 'shopping_started',
    item_found: 'item_found',
    item_substituted: 'item_substituted',
    item_unavailable: 'item_unavailable',
    shopping_completed: 'shopping_completed',
    delivery_started: 'delivery_started',
    delivered: 'delivered',
    cancelled: 'cancelled',
    status_changed: 'status_changed',
    note_added: 'note_added',
    receipt_uploaded: 'receipt_uploaded',
    # Weight variance events
    weight_updated: 'weight_updated',
    variance_auto_approved: 'variance_auto_approved',
    variance_approval_requested: 'variance_approval_requested',
    variance_approved: 'variance_approved',
    variance_rejected: 'variance_rejected',
    variance_timeout: 'variance_timeout'
  }

  validates :event_type, presence: true
  validates :occurred_at, presence: true
  validates :description, presence: true

  # Scopes for common queries
  scope :recent, -> { order(occurred_at: :desc) }
  scope :for_timeline, -> { order(occurred_at: :asc) }
  scope :status_events, -> { where(event_type: ['created', 'assigned', 'accepted', 'shopping_started', 'shopping_completed', 'receipt_uploaded', 'delivery_started', 'delivered', 'cancelled']) }
  scope :variance_events, -> { where(event_type: ['weight_updated', 'variance_auto_approved', 'variance_approval_requested', 'variance_approved', 'variance_rejected', 'variance_timeout']) }
  scope :by_user, ->(user) { where(user: user) }

  # Helper methods
  def self.create_event!(order, event_type, user = nil, description = nil, data = {})
    create!(
      order: order,
      event_type: event_type,
      user: user,
      description: description || generate_description(event_type, order, user, data),
      data: data,
      occurred_at: Time.current
    )
  end

  def user_name
    user&.name || 'System'
  end

  def formatted_time
    occurred_at.strftime('%B %d, %Y at %I:%M %p')
  end

  def time_ago
    ActionController::Base.helpers.time_ago_in_words(occurred_at)
  end

  private

  def self.generate_description(event_type, order, user, data)
    case event_type.to_s
    when 'created'
      "Order was placed by #{order.user.name}"
    when 'assigned'
      driver_name = data[:driver_name] || 'driver'
      if data[:assignment_type] == 'admin' && data[:assigned_by]
        "Admin #{data[:assigned_by]} assigned driver #{driver_name} to this order"
      else
        "Order was assigned to driver #{driver_name}"
      end
    when 'accepted'
      if data[:change_type] == 'admin_assignment'
        "Order automatically accepted when assigned by admin #{data[:changed_by]}"
      else
        driver_name = data[:driver_name] || user&.name || 'driver'
        "Driver #{driver_name} accepted the order"
      end
    when 'shopping_started'
      driver_name = data[:driver_name] || user&.name || order.driver&.name || 'Driver'
      "#{driver_name} started shopping for the order"
    when 'item_found'
      "Item '#{data[:item_name]}' was found"
    when 'item_substituted'
      "Item '#{data[:original_item]}' was substituted with '#{data[:substitute_item]}'"
    when 'item_unavailable'
      "Item '#{data[:item_name]}' was marked as unavailable"
    when 'shopping_completed'
      driver_name = data[:driver_name] || user&.name || order.driver&.name || 'Driver'
      "#{driver_name} completed shopping"
    when 'delivery_started'
      driver_name = data[:driver_name] || user&.name || order.driver&.name || 'Driver'
      "#{driver_name} started delivery to customer"
    when 'delivered'
      driver_name = data[:driver_name] || user&.name || 'driver'
      "Order was successfully delivered by #{driver_name}"
    when 'cancelled'
      if data[:change_type] == 'admin_action'
        "Order was cancelled by admin #{data[:changed_by]}"
      else
        "Order was cancelled#{user ? " by #{user.name}" : ""}"
      end
    when 'status_changed'
      "Status changed from #{data[:from_status]} to #{data[:to_status]}"
    when 'note_added'
      "Note added: #{data[:note]}"
    when 'receipt_uploaded'
      driver_name = data[:driver_name] || user&.name || order.driver&.name || 'Driver'
      "#{driver_name} uploaded store receipt"
    when 'weight_updated'
      driver_name = data[:driver_name] || user&.name || order.driver&.name || 'Driver'
      item_name = data[:item_name] || 'item'
      old_weight = data[:old_weight]
      new_weight = data[:new_weight]
      weight_unit = data[:weight_unit] || 'lbs'
      if old_weight
        "#{driver_name} updated #{item_name} weight from #{old_weight} #{weight_unit} to #{new_weight} #{weight_unit}"
      else
        "#{driver_name} weighed #{item_name}: #{new_weight} #{weight_unit}"
      end
    when 'variance_auto_approved'
      item_name = data[:item_name] || 'item'
      variance_percentage = data[:variance_percentage]
      "#{item_name} weight variance (#{variance_percentage}%) was automatically approved"
    when 'variance_approval_requested'
      item_name = data[:item_name] || 'item'
      variance_percentage = data[:variance_percentage]
      "Customer approval requested for #{item_name} weight variance (#{variance_percentage}%)"
    when 'variance_approved'
      customer_name = data[:customer_name] || user&.name || order.user&.name || 'Customer'
      item_name = data[:item_name] || 'item'
      variance_percentage = data[:variance_percentage]
      "#{customer_name} approved #{item_name} weight variance (#{variance_percentage}%)"
    when 'variance_rejected'
      customer_name = data[:customer_name] || user&.name || order.user&.name || 'Customer'
      item_name = data[:item_name] || 'item'
      variance_percentage = data[:variance_percentage]
      "#{customer_name} rejected #{item_name} weight variance (#{variance_percentage}%)"
    when 'variance_timeout'
      item_name = data[:item_name] || 'item'
      variance_percentage = data[:variance_percentage]
      "#{item_name} weight variance (#{variance_percentage}%) approval timed out"
    else
      "#{event_type.humanize} event occurred"
    end
  end
end