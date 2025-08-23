# Abstract interface for all payment service implementations
# This ensures consistent API across mock and real payment services
class Payment::PaymentServiceInterface
  # Create a payment intent for the given amount
  # @param amount [Decimal] The amount to charge in dollars
  # @param metadata [Hash] Additional data to attach to the payment
  # @return [Hash] Payment intent response with id, status, amount, etc.
  def create_payment_intent(amount, metadata = {})
    raise NotImplementedError, "Subclasses must implement create_payment_intent"
  end
  
  # Capture the final payment amount from a payment intent
  # @param payment_intent_id [String] The payment intent ID to capture
  # @param final_amount [Decimal] The final amount to capture
  # @return [Hash] Capture response with status, amount_captured, etc.
  def capture_payment(payment_intent_id, final_amount)
    raise NotImplementedError, "Subclasses must implement capture_payment"
  end
  
  # Refund a captured payment
  # @param payment_intent_id [String] The payment intent ID to refund
  # @param amount [Decimal] The amount to refund
  # @param reason [String] Optional reason for the refund
  # @return [Hash] Refund response with status, amount, refund_id, etc.
  def refund_payment(payment_intent_id, amount, reason = nil)
    raise NotImplementedError, "Subclasses must implement refund_payment"
  end
  
  # Get the current status of a payment intent
  # @param payment_intent_id [String] The payment intent ID to check
  # @return [Hash] Payment status with current state and details
  def get_payment_status(payment_intent_id)
    raise NotImplementedError, "Subclasses must implement get_payment_status"
  end
  
  # Cancel a payment intent before capture
  # @param payment_intent_id [String] The payment intent ID to cancel
  # @return [Hash] Cancellation response
  def cancel_payment_intent(payment_intent_id)
    raise NotImplementedError, "Subclasses must implement cancel_payment_intent"
  end
  
  # Validate that the service is properly configured
  # @return [Boolean] True if service is ready to process payments
  def configured?
    raise NotImplementedError, "Subclasses must implement configured?"
  end
  
  # Get the service name for logging and debugging
  # @return [String] Human-readable service name
  def service_name
    raise NotImplementedError, "Subclasses must implement service_name"
  end
end