class Payment::StripePaymentService
  include Payment::PaymentServiceInterface
  include ActiveSupport::Benchmarkable

  def initialize
    @stripe_secret_key = Rails.configuration.stripe[:secret_key]
    @test_mode = ENV['STRIPE_TEST_MODE'] == 'true' || Rails.env.development?
    
    # Set Stripe API key
    Stripe.api_key = @stripe_secret_key if @stripe_secret_key.present?
  end

  def service_name
    'stripe'
  end

  def configured?
    @stripe_secret_key.present?
  end

  def status
    return { status: 'not_configured', message: 'Stripe API key not configured' } unless configured?
    
    if @test_mode
      { status: 'test_mode', message: 'Stripe running in test mode' }
    else
      { status: 'live_mode', message: 'Stripe running in live mode' }
    end
  end

  def create_payment_intent(amount, metadata = {})
    order_id = metadata[:order_id] || 'unknown'
    buffer_percentage = metadata[:buffer_percentage] || 0
    
    benchmark "Create Stripe payment intent for order #{order_id}" do
      begin
        # Calculate amount with buffer
        buffer_amount = amount * (buffer_percentage / 100.0)
        total_amount = amount + buffer_amount
        amount_cents = (total_amount * 100).to_i

        Rails.logger.info "Creating Stripe payment intent: $#{amount} + #{buffer_percentage}% buffer = $#{total_amount}"

        if @test_mode
          # In test mode, return a mock payment intent
          payment_intent_id = "pi_test_#{SecureRandom.hex(16)}"
          client_secret = "#{payment_intent_id}_secret_#{SecureRandom.hex(8)}"
          
          Rails.logger.info "Test mode: Generated mock payment intent #{payment_intent_id}"
          
          payment_intent = {
            id: payment_intent_id,
            amount: total_amount,
            status: 'requires_confirmation',
            metadata: metadata.merge({
              original_amount: amount,
              buffer_amount: buffer_amount,
              buffer_percentage: buffer_percentage
            }),
            created_at: Time.current.iso8601,
            currency: 'usd',
            service: service_name,
            client_secret: client_secret
          }
          
          return payment_intent
        end

        # Create actual Stripe payment intent
        payment_intent = Stripe::PaymentIntent.create({
          amount: amount_cents,
          currency: 'usd',
          metadata: {
            order_id: order_id.to_s,
            original_amount: amount.to_s,
            buffer_percentage: buffer_percentage.to_s,
            buffer_amount: buffer_amount.to_s
          },
          capture_method: 'manual' # We'll capture manually after delivery
        })

        Rails.logger.info "Created Stripe payment intent: #{payment_intent.id}"

        {
          id: payment_intent.id,
          amount: total_amount,
          status: payment_intent.status,
          metadata: metadata.merge({
            original_amount: amount,
            buffer_amount: buffer_amount,
            buffer_percentage: buffer_percentage
          }),
          created_at: Time.current.iso8601,
          currency: 'usd',
          service: service_name,
          client_secret: payment_intent.client_secret
        }

      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe payment intent creation failed: #{e.message}"
        raise Payment::PaymentError, "Stripe error: #{e.message}"
      rescue => e
        Rails.logger.error "Payment intent creation failed: #{e.message}"
        raise Payment::PaymentError, "Payment processing error: #{e.message}"
      end
    end
  end

  def capture_payment_intent(payment_intent_id, final_amount = nil)
    benchmark "Capture Stripe payment intent #{payment_intent_id}" do
      begin
        if @test_mode
          Rails.logger.info "Test mode: Simulating capture of payment intent #{payment_intent_id}"
          return {
            success: true,
            payment_intent_id: payment_intent_id,
            amount_captured: final_amount,
            status: 'succeeded',
            test_mode: true
          }
        end

        # Retrieve the payment intent
        payment_intent = Stripe::PaymentIntent.retrieve(payment_intent_id)

        # Prepare capture parameters
        capture_params = {}
        if final_amount
          amount_cents = (final_amount * 100).to_i
          capture_params[:amount_to_capture] = amount_cents
        end

        # Capture the payment
        captured_intent = payment_intent.capture(capture_params)

        Rails.logger.info "Captured Stripe payment intent: #{captured_intent.id}"

        {
          success: true,
          payment_intent_id: captured_intent.id,
          amount_captured: (captured_intent.amount_received || captured_intent.amount) / 100.0,
          status: captured_intent.status
        }

      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe payment capture failed: #{e.message}"
        {
          success: false,
          error: e.message,
          error_type: 'stripe_error'
        }
      rescue => e
        Rails.logger.error "Payment capture failed: #{e.message}"
        {
          success: false,
          error: "Payment capture error: #{e.message}",
          error_type: 'system_error'
        }
      end
    end
  end

  def refund_payment(payment_intent_id, refund_amount, reason = nil)
    benchmark "Refund Stripe payment #{payment_intent_id}" do
      begin
        if @test_mode
          Rails.logger.info "Test mode: Simulating refund of $#{refund_amount} for payment intent #{payment_intent_id}"
          return {
            success: true,
            refund_id: "re_test_#{SecureRandom.hex(12)}",
            amount_refunded: refund_amount,
            status: 'succeeded',
            test_mode: true
          }
        end

        # Create refund
        refund = Stripe::Refund.create({
          payment_intent: payment_intent_id,
          amount: (refund_amount * 100).to_i,
          reason: reason || 'requested_by_customer'
        })

        Rails.logger.info "Created Stripe refund: #{refund.id}"

        {
          success: true,
          refund_id: refund.id,
          amount_refunded: refund.amount / 100.0,
          status: refund.status
        }

      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe refund failed: #{e.message}"
        {
          success: false,
          error: e.message,
          error_type: 'stripe_error'
        }
      rescue => e
        Rails.logger.error "Refund failed: #{e.message}"
        {
          success: false,
          error: "Refund error: #{e.message}",
          error_type: 'system_error'
        }
      end
    end
  end

  def retrieve_payment_intent(payment_intent_id)
    benchmark "Retrieve Stripe payment intent #{payment_intent_id}" do
      begin
        if @test_mode
          Rails.logger.info "Test mode: Simulating retrieval of payment intent #{payment_intent_id}"
          return {
            success: true,
            payment_intent_id: payment_intent_id,
            amount: 10.00, # Mock amount
            status: 'succeeded',
            test_mode: true
          }
        end

        payment_intent = Stripe::PaymentIntent.retrieve(payment_intent_id)

        {
          success: true,
          payment_intent_id: payment_intent.id,
          amount: payment_intent.amount / 100.0,
          status: payment_intent.status,
          metadata: payment_intent.metadata
        }

      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe payment intent retrieval failed: #{e.message}"
        {
          success: false,
          error: e.message,
          error_type: 'stripe_error'
        }
      rescue => e
        Rails.logger.error "Payment intent retrieval failed: #{e.message}"
        {
          success: false,
          error: "Retrieval error: #{e.message}",
          error_type: 'system_error'
        }
      end
    end
  end

  def cancel_payment_intent(payment_intent_id, reason = nil)
    benchmark "Cancel Stripe payment intent #{payment_intent_id}" do
      begin
        if @test_mode
          Rails.logger.info "Test mode: Simulating cancellation of payment intent #{payment_intent_id}"
          return {
            success: true,
            payment_intent_id: payment_intent_id,
            status: 'canceled',
            test_mode: true
          }
        end

        payment_intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
        canceled_intent = payment_intent.cancel({
          cancellation_reason: reason || 'requested_by_customer'
        })

        Rails.logger.info "Canceled Stripe payment intent: #{canceled_intent.id}"

        {
          success: true,
          payment_intent_id: canceled_intent.id,
          status: canceled_intent.status
        }

      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe payment intent cancellation failed: #{e.message}"
        {
          success: false,
          error: e.message,
          error_type: 'stripe_error'
        }
      rescue => e
        Rails.logger.error "Payment intent cancellation failed: #{e.message}"
        {
          success: false,
          error: "Cancellation error: #{e.message}",
          error_type: 'system_error'
        }
      end
    end
  end

  private

  def logger
    Rails.logger
  end
  
  # Payment error class for Stripe-specific errors
  class PaymentError < StandardError; end
end