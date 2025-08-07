class SmsService
  # Cost-optimized SMS templates for order notifications
  # 4 key messages per order to balance user experience with SMS costs
  
  TEMPLATES = {
    order_confirmed: "Hafa Adai! Your $%{total} order with Guahan Grocer is confirmed. We're finding a driver for you. Track your order: %{tracking_url}",
    driver_assigned: "Good news! Your order was accepted by %{driver_name} and will arrive in about %{eta} minutes.",
    out_for_delivery: "Your Guahan Grocer order is on the way! %{driver_name} will be there in about %{eta} minutes.",
    delivered: "Your order has been delivered! Si Yu'os Ma'åse for choosing Guahan Grocer. 🌺"
  }.freeze

  def self.send_order_notification(phone:, template:, variables: {})
    return false if phone.blank? || template.blank?
    
    message_template = TEMPLATES[template.to_sym]
    return false unless message_template
    
    # Cost optimization checks
    estimated_cost = 0.10 # 10 cents per SMS
    
    # Check daily spending limit
    unless SmsCostOptimizer.can_send_sms?(estimated_cost)
      Rails.logger.warn("[SmsService] SMS blocked by cost optimizer - daily limit reached")
      return false
    end
    
    # Check for duplicate recent messages (include order_id if available)
    order_id = variables[:order_id]
    if SmsCostOptimizer.recently_sent_similar?(phone, template, order_id)
      Rails.logger.warn("[SmsService] SMS blocked by cost optimizer - recent duplicate")
      return false
    end
    
    # Generate the message text
    message = message_template % variables
    
    # Log the SMS attempt
    Rails.logger.info("[SmsService] Sending #{template} SMS to #{phone}")
    
    # Create SMS record for tracking
    sms_message = SmsMessage.create!(
      phone: phone,
      message: message,
      status: 'pending'
    )
    
    # Send via ClickSend
    success = ClicksendClient.send_text_message(
      to: phone,
      body: message
    )
    
    # Update SMS record status and record cost
    if success
      sms_message.update!(
        status: 'sent',
        sent_at: Time.current
      )
      
      # Record the cost for tracking
      SmsCostOptimizer.record_sms_cost(estimated_cost)
      
      Rails.logger.info("[SmsService] Successfully sent #{template} SMS to #{phone}")
    else
      sms_message.update!(status: 'failed')
      Rails.logger.error("[SmsService] Failed to send #{template} SMS to #{phone}")
    end
    
    success
  rescue StandardError => e
    Rails.logger.error("[SmsService] Error sending SMS: #{e.message}")
    sms_message&.update!(status: 'failed')
    false
  end

  # Helper method to generate deep link for order tracking
  # Uses app deep link with web fallback via universal link
  def self.tracking_url(order_id)
    # For now, use web URL which can redirect to app if installed
    # TODO: Implement universal links for seamless app/web fallback
    web_url = ENV.fetch('FRONTEND_URL', 'https://guahan-grocer.netlify.app')
    "#{web_url}/order-detail/#{order_id}"
  end

  # Helper method to generate rating URL (not used currently)
  def self.rating_url(order_id)
    app_scheme = "guahangrocer://rate-order/#{order_id}"
    app_scheme
  end

  # Estimate ETA based on order status and delivery calculations
  def self.estimate_eta(order)
    eta = case order.status
    when 'accepted'
      # Base shopping time + delivery time
      shopping_time = 20 # minutes
      delivery_time = order.store_distance_miles ? (order.store_distance_miles * 2).to_i : 15
      shopping_time + delivery_time
    when 'shopping'
      # Just delivery time from store to customer
      order.store_distance_miles ? (order.store_distance_miles * 2).to_i : 15
    when 'delivering'
      # Use the calculated estimated delivery minutes if available, or calculate from distance
      if order.estimated_delivery_minutes.present?
        order.estimated_delivery_minutes.to_i
      elsif order.store_distance_miles.present?
        (order.store_distance_miles * 2).to_i
      else
        10
      end
    else
      # Use existing ETA from order or fallback
      order.eta&.to_i || 30
    end
    
    # Ensure we always return a positive integer
    [eta.to_i, 5].max
  end
end