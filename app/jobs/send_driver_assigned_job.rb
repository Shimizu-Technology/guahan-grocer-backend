class SendDriverAssignedJob < ApplicationJob
  queue_as :critical  # High priority queue for immediate notifications

  def perform(order_id)
    order = Order.find(order_id)
    user = order.user
    driver = order.driver
    
    Rails.logger.info("[SendDriverAssignedJob] Processing driver assignment notification for order ##{order.id}")
    
    unless driver
      Rails.logger.warn("[SendDriverAssignedJob] No driver assigned to order ##{order.id}")
      return
    end
    
    variables = {
      order_id: order.id,
      driver_name: driver.name,
      eta: SmsService.estimate_eta(order)
    }
    
    SmsService.send_order_notification(
      phone: user.phone,
      template: :driver_assigned,
      variables: variables
    )
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[SendDriverAssignedJob] Order not found: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[SendDriverAssignedJob] Failed to send driver assignment SMS: #{e.message}")
    raise # Re-raise to trigger Sidekiq retry
  end
end