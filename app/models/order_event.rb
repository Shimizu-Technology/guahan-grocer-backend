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
    note_added: 'note_added'
  }

  validates :event_type, presence: true
  validates :occurred_at, presence: true
  validates :description, presence: true

  # Scopes for common queries
  scope :recent, -> { order(occurred_at: :desc) }
  scope :for_timeline, -> { order(occurred_at: :asc) }
  scope :status_events, -> { where(event_type: ['created', 'assigned', 'accepted', 'shopping_started', 'shopping_completed', 'delivery_started', 'delivered', 'cancelled']) }
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
      "Order was assigned to driver #{data[:driver_name] || user&.name}"
    when 'accepted'
      "Order was accepted by driver #{user&.name}"
    when 'shopping_started'
      "Driver #{user&.name} started shopping"
    when 'item_found'
      "Item '#{data[:item_name]}' was found"
    when 'item_substituted'
      "Item '#{data[:original_item]}' was substituted with '#{data[:substitute_item]}'"
    when 'item_unavailable'
      "Item '#{data[:item_name]}' was marked as unavailable"
    when 'shopping_completed'
      "Driver #{user&.name} completed shopping"
    when 'delivery_started'
      "Driver #{user&.name} started delivery"
    when 'delivered'
      "Order was delivered by #{user&.name}"
    when 'cancelled'
      "Order was cancelled#{user ? " by #{user.name}" : ""}"
    when 'status_changed'
      "Status changed from #{data[:from_status]} to #{data[:to_status]}"
    when 'note_added'
      "Note added: #{data[:note]}"
    else
      "#{event_type.humanize} event occurred"
    end
  end
end