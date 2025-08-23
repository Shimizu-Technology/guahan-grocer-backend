# High-level payment processing service that handles business logic
# This service orchestrates payment operations using the underlying payment service
class Payment::PaymentProcessor
  include ActiveSupport::Benchmarkable
  
  attr_reader :payment_service
  
  private
  
  def logger
    Rails.logger
  end
  
  public
  
  def initialize(payment_service = nil)
    @payment_service = payment_service || Payment::PaymentService.current
  end
  
  # Create and authorize a payment for an order
  # @param order [Order] The order to create payment for
  # @param buffer_percentage [Float] Additional percentage to authorize (default 25%)
  # @return [Hash] Payment authorization result
  def authorize_payment_for_order(order, buffer_percentage = 0.25)
    estimated_total = calculate_estimated_total(order)
    pre_auth_amount = calculate_pre_auth_amount(estimated_total, buffer_percentage)
    
    metadata = build_payment_metadata(order, estimated_total, pre_auth_amount)
    
    begin
      payment_intent = benchmark "Payment authorization for order #{order.id}" do
        payment_service.create_payment_intent(pre_auth_amount, metadata)
      end
      
      # Update order with payment information
      order.update!(
        estimated_total: estimated_total,
        pre_auth_amount: pre_auth_amount,
        payment_intent_id: payment_intent[:id],
        payment_status: 'authorized',
        payment_method: payment_service.is_a?(Payment::MockPaymentService) ? 'mock' : 'stripe'
      )
      
      Rails.logger.info "Payment authorized for order #{order.id}: #{payment_intent[:id]} - $#{pre_auth_amount}"
      
      {
        success: true,
        payment_intent: payment_intent,
        estimated_total: estimated_total,
        pre_auth_amount: pre_auth_amount
      }
      
    rescue => e
      Rails.logger.error "Payment authorization failed for order #{order.id}: #{e.message}"
      
      order.update!(payment_status: 'failed')
      
      {
        success: false,
        error: e.message,
        estimated_total: estimated_total
      }
    end
  end
  
  # Capture the final payment amount after order completion
  # @param order [Order] The completed order
  # @return [Hash] Payment capture result
  def capture_final_payment(order)
    unless order.payment_intent_id
      raise PaymentError, "No payment intent found for order #{order.id}"
    end
    
    final_total = calculate_final_total(order)
    
    begin
      capture_result = benchmark "Payment capture for order #{order.id}" do
        payment_service.capture_payment(order.payment_intent_id, final_total)
      end
      
      # Update order with final payment information
      order.update!(
        final_total: final_total,
        payment_status: 'completed'
      )
      
      Rails.logger.info "Payment captured for order #{order.id}: $#{final_total}"
      
      # Process any refunds if pre-auth was higher than final amount
      refund_result = process_overage_refund(order)
      
      {
        success: true,
        capture_result: capture_result,
        final_total: final_total,
        refund_result: refund_result
      }
      
    rescue => e
      Rails.logger.error "Payment capture failed for order #{order.id}: #{e.message}"
      
      order.update!(payment_status: 'capture_failed')
      
      {
        success: false,
        error: e.message,
        final_total: final_total
      }
    end
  end
  
  # Process a refund for variance adjustments
  # @param order [Order] The order to refund
  # @param amount [Decimal] The amount to refund
  # @param reason [String] Reason for the refund
  # @return [Hash] Refund result
  def process_variance_refund(order, amount, reason = "Weight variance adjustment")
    unless order.payment_intent_id
      raise PaymentError, "No payment intent found for order #{order.id}"
    end
    
    unless order.payment_status == 'completed'
      raise PaymentError, "Cannot refund order #{order.id} with status: #{order.payment_status}"
    end
    
    begin
      refund_result = benchmark "Variance refund for order #{order.id}" do
        payment_service.refund_payment(order.payment_intent_id, amount, reason)
      end
      
      Rails.logger.info "Variance refund processed for order #{order.id}: $#{amount} - #{reason}"
      
      {
        success: true,
        refund_result: refund_result,
        amount: amount,
        reason: reason
      }
      
    rescue => e
      Rails.logger.error "Variance refund failed for order #{order.id}: #{e.message}"
      
      {
        success: false,
        error: e.message,
        amount: amount,
        reason: reason
      }
    end
  end
  
  # Cancel a payment authorization
  # @param order [Order] The order to cancel payment for
  # @return [Hash] Cancellation result
  def cancel_payment_authorization(order)
    unless order.payment_intent_id
      raise PaymentError, "No payment intent found for order #{order.id}"
    end
    
    begin
      cancellation_result = benchmark "Payment cancellation for order #{order.id}" do
        payment_service.cancel_payment_intent(order.payment_intent_id)
      end
      
      order.update!(payment_status: 'cancelled')
      
      Rails.logger.info "Payment authorization cancelled for order #{order.id}"
      
      {
        success: true,
        cancellation_result: cancellation_result
      }
      
    rescue => e
      Rails.logger.error "Payment cancellation failed for order #{order.id}: #{e.message}"
      
      {
        success: false,
        error: e.message
      }
    end
  end
  
  # Get payment status for an order
  # @param order [Order] The order to check
  # @return [Hash] Payment status information
  def get_payment_status(order)
    unless order.payment_intent_id
      return {
        order_id: order.id,
        payment_status: order.payment_status,
        has_payment_intent: false
      }
    end
    
    begin
      payment_status = payment_service.get_payment_status(order.payment_intent_id)
      
      {
        order_id: order.id,
        payment_status: order.payment_status,
        has_payment_intent: true,
        payment_service_status: payment_status,
        estimated_total: order.estimated_total,
        pre_auth_amount: order.pre_auth_amount,
        final_total: order.final_total
      }
      
    rescue => e
      Rails.logger.error "Failed to get payment status for order #{order.id}: #{e.message}"
      
      {
        order_id: order.id,
        payment_status: order.payment_status,
        has_payment_intent: true,
        error: e.message
      }
    end
  end
  
  private
  
  def calculate_estimated_total(order)
    # For now, use the existing total
    # Later we'll calculate based on estimated weights for weight-based items
    order.total || order.order_items.sum { |item| item.price * item.quantity }
  end
  
  def calculate_pre_auth_amount(estimated_total, buffer_percentage)
    (estimated_total * (1 + buffer_percentage)).round(2)
  end
  
  def calculate_final_total(order)
    # Calculate final total including any weight variance adjustments
    base_total = order.order_items.sum do |item|
      if item.actual_price.present?
        item.actual_price * (item.found_quantity || item.quantity)
      else
        item.price * (item.found_quantity || item.quantity)
      end
    end
    
    # Add delivery fee, tip, etc.
    final_total = base_total + (order.delivery_fee || 0) + (order.tip_amount || 0)
    final_total.round(2)
  end
  
  def process_overage_refund(order)
    return nil unless order.pre_auth_amount && order.final_total
    
    overage = order.pre_auth_amount - order.final_total
    
    if overage > 0.01  # Only refund if overage is more than 1 cent
      process_variance_refund(order, overage, "Pre-authorization overage refund")
    else
      nil
    end
  end
  
  def build_payment_metadata(order, estimated_total, pre_auth_amount)
    {
      order_id: order.id,
      user_id: order.user_id,
      estimated_total: estimated_total.to_s,
      pre_auth_amount: pre_auth_amount.to_s,
      order_status: order.status,
      service: payment_service.service_name,
      created_at: Time.current.iso8601
    }
  end
  
  # Custom error class for payment processing errors
  class PaymentError < StandardError; end
end