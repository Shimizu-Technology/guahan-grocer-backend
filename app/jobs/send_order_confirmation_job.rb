class SendOrderConfirmationJob < ApplicationJob
  queue_as :critical  # High priority queue for immediate notifications

  def perform(order_id)
    order = Order.find(order_id)
    user = order.user
    
    Rails.logger.info("[SendOrderConfirmationJob] Processing order confirmation for order ##{order.id}")
    
    variables = {
      total: sprintf("%.2f", order.total.to_f),
      order_id: order.id,
      tracking_url: SmsService.tracking_url(order.id)
    }
    
    SmsService.send_order_notification(
      phone: user.phone,
      template: :order_confirmed,
      variables: variables
    )
    
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[SendOrderConfirmationJob] Order not found: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("[SendOrderConfirmationJob] Failed to send confirmation SMS: #{e.message}")
    raise # Re-raise to trigger Sidekiq retry
  end
end