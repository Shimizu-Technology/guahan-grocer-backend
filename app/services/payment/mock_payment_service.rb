# Mock payment service for development and testing
# Simulates payment processing without actually charging cards
class Payment::MockPaymentService
  include Payment::PaymentServiceInterface
  include ActiveSupport::Benchmarkable
  
  def initialize
    @payment_intents = {}
    @captures = {}
    @refunds = {}
  end
  
  def create_payment_intent(amount, metadata = {})
    payment_intent_id = generate_payment_intent_id
    
    payment_intent = {
      id: payment_intent_id,
      amount: amount.to_f,
      status: 'requires_confirmation',
      metadata: metadata,
      created_at: Time.current.iso8601,
      currency: 'usd',
      service: service_name
    }
    
    @payment_intents[payment_intent_id] = payment_intent
    
    log_payment_action("Created payment intent", payment_intent_id, amount, metadata)
    
    payment_intent
  end
  
  def capture_payment(payment_intent_id, final_amount)
    payment_intent = find_payment_intent!(payment_intent_id)
    
    unless payment_intent[:status] == 'requires_confirmation'
      raise PaymentError, "Cannot capture payment intent with status: #{payment_intent[:status]}"
    end
    
    capture_id = generate_capture_id
    captured_at = Time.current.iso8601
    
    capture_response = {
      id: capture_id,
      payment_intent_id: payment_intent_id,
      status: 'succeeded',
      amount_captured: final_amount.to_f,
      captured_at: captured_at,
      service: service_name
    }
    
    @captures[capture_id] = capture_response
    @payment_intents[payment_intent_id][:status] = 'succeeded'
    @payment_intents[payment_intent_id][:captured_amount] = final_amount.to_f
    @payment_intents[payment_intent_id][:captured_at] = captured_at
    
    log_payment_action("Captured payment", payment_intent_id, final_amount)
    
    capture_response
  end
  
  def refund_payment(payment_intent_id, amount, reason = nil)
    payment_intent = find_payment_intent!(payment_intent_id)
    
    unless payment_intent[:status] == 'succeeded'
      raise PaymentError, "Cannot refund payment intent with status: #{payment_intent[:status]}"
    end
    
    captured_amount = payment_intent[:captured_amount] || 0
    if amount > captured_amount
      raise PaymentError, "Cannot refund $#{amount} - only $#{captured_amount} was captured"
    end
    
    refund_id = generate_refund_id
    processed_at = Time.current.iso8601
    
    refund_response = {
      id: refund_id,
      payment_intent_id: payment_intent_id,
      status: 'succeeded',
      amount: amount.to_f,
      reason: reason,
      processed_at: processed_at,
      service: service_name
    }
    
    @refunds[refund_id] = refund_response
    
    log_payment_action("Processed refund", payment_intent_id, amount, { reason: reason })
    
    refund_response
  end
  
  def get_payment_status(payment_intent_id)
    find_payment_intent!(payment_intent_id)
  end
  
  def cancel_payment_intent(payment_intent_id)
    payment_intent = find_payment_intent!(payment_intent_id)
    
    unless payment_intent[:status] == 'requires_confirmation'
      raise PaymentError, "Cannot cancel payment intent with status: #{payment_intent[:status]}"
    end
    
    @payment_intents[payment_intent_id][:status] = 'canceled'
    @payment_intents[payment_intent_id][:canceled_at] = Time.current.iso8601
    
    log_payment_action("Canceled payment intent", payment_intent_id)
    
    {
      id: payment_intent_id,
      status: 'canceled',
      canceled_at: @payment_intents[payment_intent_id][:canceled_at],
      service: service_name
    }
  end
  
  def configured?
    true # Mock service is always ready
  end
  
  def service_name
    "Mock Payment Service"
  end
  
  # Development helpers for testing scenarios
  def simulate_payment_failure(payment_intent_id, error_message = "Simulated payment failure")
    if @payment_intents[payment_intent_id]
      @payment_intents[payment_intent_id][:status] = 'failed'
      @payment_intents[payment_intent_id][:error] = error_message
      log_payment_action("Simulated failure", payment_intent_id, nil, { error: error_message })
    end
  end
  
  def get_all_payments
    {
      payment_intents: @payment_intents,
      captures: @captures,
      refunds: @refunds,
      service: service_name
    }
  end
  
  def clear_test_data!
    @payment_intents.clear
    @captures.clear
    @refunds.clear
    Rails.logger.info "Mock Payment Service: Cleared all test data"
  end
  
  private
  
  def find_payment_intent!(payment_intent_id)
    payment_intent = @payment_intents[payment_intent_id]
    
    unless payment_intent
      raise PaymentError, "Payment intent not found: #{payment_intent_id}"
    end
    
    payment_intent
  end
  
  def generate_payment_intent_id
    "pi_mock_#{SecureRandom.hex(12)}"
  end
  
  def generate_capture_id
    "cap_mock_#{SecureRandom.hex(8)}"
  end
  
  def generate_refund_id
    "re_mock_#{SecureRandom.hex(8)}"
  end
  
  def log_payment_action(action, payment_intent_id, amount = nil, metadata = {})
    log_message = "Mock Payment: #{action}"
    log_message += " - #{payment_intent_id}" if payment_intent_id
    log_message += " - $#{amount}" if amount
    log_message += " - #{metadata}" if metadata.any?
    
    Rails.logger.info log_message
  end
  
  # Custom error class for payment-related errors
  class PaymentError < StandardError; end
end