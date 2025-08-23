# Service for handling various types of notifications
class NotificationService
  include ActiveSupport::Benchmarkable

  def self.send_variance_approval_notification(order_item)
    new.send_variance_approval_notification(order_item)
  end

  def self.send_variance_approved_notification(order_item)
    new.send_variance_approved_notification(order_item)
  end

  def self.send_variance_rejected_notification(order_item)
    new.send_variance_rejected_notification(order_item)
  end

  def self.send_variance_timeout_notification(order_item)
    new.send_variance_timeout_notification(order_item)
  end

  def send_variance_approval_notification(order_item)
    return unless order_item&.order&.user

    user = order_item.order.user
    product_name = order_item.product&.name || 'Unknown item'
    
    benchmark "Send variance approval notification for order #{order_item.order.id}" do
      case user.variance_notification_method
      when 'push'
        send_push_notification(user, {
          title: "Weight Variance Approval Needed",
          body: "#{product_name} weight differs from requested. Tap to review.",
          data: {
            type: 'variance_approval',
            order_id: order_item.order.id,
            order_item_id: order_item.id,
            product_name: product_name,
            estimated_weight: order_item.estimated_weight,
            actual_weight: order_item.actual_weight,
            variance_percentage: order_item.variance_percentage
          }
        })
      when 'sms'
        send_sms_notification(user, variance_approval_sms_message(order_item))
      end
    end
  rescue => e
    Rails.logger.error "Failed to send variance approval notification: #{e.message}"
  end

  def send_variance_approved_notification(order_item)
    return unless order_item&.order&.user

    user = order_item.order.user
    product_name = order_item.product&.name || 'Unknown item'
    
    benchmark "Send variance approved notification for order #{order_item.order.id}" do
      case user.variance_notification_method
      when 'push'
        send_push_notification(user, {
          title: "Weight Variance Approved",
          body: "#{product_name} variance approved. Your order continues.",
          data: {
            type: 'variance_approved',
            order_id: order_item.order.id,
            order_item_id: order_item.id,
            product_name: product_name
          }
        })
      when 'sms'
        send_sms_notification(user, variance_approved_sms_message(order_item))
      end
    end
  rescue => e
    Rails.logger.error "Failed to send variance approved notification: #{e.message}"
  end

  def send_variance_rejected_notification(order_item)
    return unless order_item&.order&.user

    user = order_item.order.user
    product_name = order_item.product&.name || 'Unknown item'
    
    benchmark "Send variance rejected notification for order #{order_item.order.id}" do
      case user.variance_notification_method
      when 'push'
        send_push_notification(user, {
          title: "Weight Variance Rejected",
          body: "#{product_name} variance rejected. Your order may be updated.",
          data: {
            type: 'variance_rejected',
            order_id: order_item.order.id,
            order_item_id: order_item.id,
            product_name: product_name
          }
        })
      when 'sms'
        send_sms_notification(user, variance_rejected_sms_message(order_item))
      end
    end
  rescue => e
    Rails.logger.error "Failed to send variance rejected notification: #{e.message}"
  end

  def send_variance_timeout_notification(order_item)
    return unless order_item&.order&.user

    user = order_item.order.user
    product_name = order_item.product&.name || 'Unknown item'
    
    benchmark "Send variance timeout notification for order #{order_item.order.id}" do
      case user.variance_notification_method
      when 'push'
        send_push_notification(user, {
          title: "Weight Variance Auto-Rejected",
          body: "#{product_name} variance timed out and was auto-rejected.",
          data: {
            type: 'variance_timeout',
            order_id: order_item.order.id,
            order_item_id: order_item.id,
            product_name: product_name
          }
        })
      when 'sms'
        send_sms_notification(user, variance_timeout_sms_message(order_item))
      end
    end
  rescue => e
    Rails.logger.error "Failed to send variance timeout notification: #{e.message}"
  end

  private

  def send_push_notification(user, notification_data)
    # TODO: Integrate with actual push notification service (e.g., Firebase, OneSignal)
    # For now, we'll log the notification
    Rails.logger.info "PUSH NOTIFICATION: #{notification_data[:title]} - #{notification_data[:body]} (User: #{user.id})"
    
    # In a real implementation, you would:
    # 1. Use a service like Firebase Cloud Messaging (FCM)
    # 2. Store user device tokens
    # 3. Send notifications to their registered devices
    # 
    # Example:
    # FCMService.send_notification(
    #   device_tokens: user.device_tokens,
    #   title: notification_data[:title],
    #   body: notification_data[:body],
    #   data: notification_data[:data]
    # )
    
    true
  end

  def send_sms_notification(user, message)
    # TODO: Integrate with actual SMS service (e.g., Twilio)
    # For now, we'll log the SMS
    Rails.logger.info "SMS NOTIFICATION: #{message} (User: #{user.id}, Phone: #{user.phone})"
    
    # In a real implementation, you would:
    # 1. Use a service like Twilio
    # 2. Send SMS to user's phone number
    # 
    # Example:
    # TwilioService.send_sms(
    #   to: user.phone,
    #   body: message
    # )
    
    true
  end

  def variance_approval_sms_message(order_item)
    product_name = order_item.product&.name || 'Unknown item'
    variance_text = if order_item.variance_percentage > 0
      "#{order_item.variance_percentage.round(1)}% more"
    else
      "#{order_item.variance_percentage.abs.round(1)}% less"
    end
    
    "Guahan Grocer: #{product_name} found with #{variance_text} weight than requested. " \
    "Please review and approve/reject in the app. Order ##{order_item.order.id}"
  end

  def variance_approved_sms_message(order_item)
    product_name = order_item.product&.name || 'Unknown item'
    "Guahan Grocer: #{product_name} weight variance approved. Your order continues. Order ##{order_item.order.id}"
  end

  def variance_rejected_sms_message(order_item)
    product_name = order_item.product&.name || 'Unknown item'
    "Guahan Grocer: #{product_name} weight variance rejected. Your order may be updated. Order ##{order_item.order.id}"
  end

  def variance_timeout_sms_message(order_item)
    product_name = order_item.product&.name || 'Unknown item'
    "Guahan Grocer: #{product_name} weight variance timed out and was auto-rejected. Order ##{order_item.order.id}"
  end

  def logger
    Rails.logger
  end
end