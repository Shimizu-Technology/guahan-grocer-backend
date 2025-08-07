class SendDeliveryCompleteJob < ApplicationJob
  queue_as :critical  # High priority queue for immediate notifications

  def perform(order_id)
    order = Order.find(order_id)
    user = order.user
    
    Rails.logger.info("[SendDeliveryCompleteJob] Processing delivery completion notification for order ##{order.id}")
    
    variables = {
      order_id: order.id
    }
    
    SmsService.send_order_notification(
      phone: user.phone,
      template: :delivered,
      variables: variables
    )
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[SendDeliveryCompleteJob] Order not found: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[SendDeliveryCompleteJob] Failed to send delivery completion SMS: #{e.message}")
    raise # Re-raise to trigger Sidekiq retry
  end
end