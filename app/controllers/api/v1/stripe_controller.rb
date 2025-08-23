class Api::V1::StripeController < ApplicationController
  before_action :authenticate_user!, except: [:webhook]
  
  # Create a payment intent for Stripe
  def create_intent
    begin
      # Get amount and currency from params
      amount_dollars = params[:amount].to_f
      currency = params[:currency] || "USD"
      
      # Convert to cents for Stripe
      amount_cents = (amount_dollars * 100).to_i
      
      Rails.logger.info("Creating Stripe payment intent for $#{amount_dollars} (#{amount_cents} cents)")
      
      # Check if we should use test mode
      test_mode = ENV['STRIPE_TEST_MODE'] == 'true' || Rails.env.development?
      
      if test_mode
        # In test mode, return a mock response
        render json: {
          success: true,
          client_secret: "pi_test_#{SecureRandom.hex(16)}_secret_#{SecureRandom.hex(8)}",
          test_mode: true
        }
        return
      end
      
      # Create payment intent with Stripe
      payment_intent = Stripe::PaymentIntent.create({
        amount: amount_cents,
        currency: currency.downcase,
        metadata: {
          user_id: current_user&.id,
          amount_dollars: amount_dollars.to_s
        }
      })
      
      render json: {
        success: true,
        client_secret: payment_intent.client_secret,
        payment_intent_id: payment_intent.id
      }
      
    rescue Stripe::StripeError => e
      Rails.logger.error("Stripe error: #{e.message}")
      render json: { 
        success: false,
        error: e.message 
      }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("Payment intent creation error: #{e.message}")
      render json: { 
        success: false,
        error: "An unexpected error occurred" 
      }, status: :internal_server_error
    end
  end

  # Get details about a payment intent
  def payment_intent
    id = params[:id]

    begin
      payment_intent = Stripe::PaymentIntent.retrieve(id)
      render json: {
        id: payment_intent.id,
        amount: payment_intent.amount,
        status: payment_intent.status,
        client_secret: payment_intent.client_secret
      }
    rescue Stripe::StripeError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      render json: { error: "An unexpected error occurred" }, status: :internal_server_error
    end
  end

  # Confirm a payment intent (if needed server-side)
  def confirm_intent
    id = params[:payment_intent_id]

    begin
      payment_intent = Stripe::PaymentIntent.retrieve(id)

      if payment_intent.status == "requires_confirmation"
        payment_intent = payment_intent.confirm
      end

      render json: {
        id: payment_intent.id,
        status: payment_intent.status,
        client_secret: payment_intent.client_secret
      }
    rescue Stripe::StripeError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue => e
      render json: { error: "An unexpected error occurred" }, status: :internal_server_error
    end
  end

  # Handle Stripe webhooks
  def webhook
    payload = request.body.read
    signature = request.env["HTTP_STRIPE_SIGNATURE"]
    
    begin
      # Verify webhook signature
      webhook_secret = Rails.configuration.stripe[:webhook_secret]
      event = Stripe::Webhook.construct_event(
        payload, signature, webhook_secret
      )
      
      Rails.logger.info("Received Stripe webhook: #{event['type']}")
      
      # Handle the event based on its type
      case event["type"]
      when "payment_intent.succeeded"
        payment_intent = event["data"]["object"]
        handle_payment_success(payment_intent)
        
      when "payment_intent.payment_failed"
        payment_intent = event["data"]["object"]
        handle_payment_failure(payment_intent)
        
      when "payment_intent.requires_action"
        payment_intent = event["data"]["object"]
        handle_payment_requires_action(payment_intent)
        
      when "charge.refunded"
        charge = event["data"]["object"]
        handle_refund(charge)
        
      when "charge.dispute.created"
        dispute = event["data"]["object"]
        handle_dispute_created(dispute)
        
      else
        Rails.logger.info "Unhandled Stripe webhook event type: #{event['type']}"
      end
      
      render json: { status: "success" }
      
    rescue JSON::ParserError => e
      Rails.logger.error("Invalid Stripe webhook payload: #{e.message}")
      render json: { error: "Invalid payload" }, status: :bad_request
    rescue Stripe::SignatureVerificationError => e
      Rails.logger.error("Invalid Stripe webhook signature: #{e.message}")
      render json: { error: "Invalid signature" }, status: :bad_request
    rescue => e
      Rails.logger.error("Stripe webhook error: #{e.message}")
      render json: { error: "Webhook error" }, status: :internal_server_error
    end
  end

  private

  def handle_payment_success(payment_intent)
    # Find order by payment_intent_id
    order = Order.find_by(payment_intent_id: payment_intent.id)
    
    if order
      order.update!(
        payment_status: "paid",
        payment_method: "stripe",
        payment_amount: payment_intent.amount / 100.0, # Convert from cents
        final_total: payment_intent.amount / 100.0
      )
      
      Rails.logger.info("Payment succeeded for order #{order.id}")
      
      # Send confirmation notifications if needed
      NotificationService.send_payment_confirmation_notification(order)
    else
      Rails.logger.warn("No order found for payment_intent: #{payment_intent.id}")
    end
  end

  def handle_payment_failure(payment_intent)
    # Find order by payment_intent_id
    order = Order.find_by(payment_intent_id: payment_intent.id)
    
    if order
      order.update!(
        payment_status: "failed",
        payment_method: "stripe"
      )
      
      Rails.logger.info("Payment failed for order #{order.id}")
      
      # Send failure notification if needed
      NotificationService.send_payment_failure_notification(order)
    else
      Rails.logger.warn("No order found for payment_intent: #{payment_intent.id}")
    end
  end

  def handle_payment_requires_action(payment_intent)
    # Find order by payment_intent_id
    order = Order.find_by(payment_intent_id: payment_intent.id)
    
    if order
      order.update!(
        payment_status: "requires_action",
        payment_method: "stripe"
      )
      
      Rails.logger.info("Payment requires action for order #{order.id}")
    else
      Rails.logger.warn("No order found for payment_intent: #{payment_intent.id}")
    end
  end

  def handle_refund(charge)
    payment_intent_id = charge.payment_intent
    order = Order.find_by(payment_intent_id: payment_intent_id)
    
    if order
      refund_amount = charge.amount_refunded / 100.0 # Convert from cents
      
      order.update!(
        payment_status: "refunded",
        refund_amount: refund_amount
      )
      
      Rails.logger.info("Refund processed for order #{order.id}: $#{refund_amount}")
      
      # Send refund notification
      NotificationService.send_refund_notification(order, refund_amount)
    else
      Rails.logger.warn("No order found for payment_intent: #{payment_intent_id}")
    end
  end

  def handle_dispute_created(dispute)
    payment_intent_id = dispute.payment_intent
    order = Order.find_by(payment_intent_id: payment_intent_id)
    
    if order
      order.update!(
        payment_status: "disputed",
        dispute_reason: dispute.reason
      )
      
      Rails.logger.info("Dispute created for order #{order.id}: #{dispute.reason}")
      
      # Notify admin about dispute
      NotificationService.send_dispute_notification(order, dispute)
    else
      Rails.logger.warn("No order found for payment_intent: #{payment_intent_id}")
    end
  end
end