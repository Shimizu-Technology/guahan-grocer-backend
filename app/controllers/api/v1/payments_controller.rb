class Api::V1::PaymentsController < ApplicationController
  before_action :set_order, only: [:authorize, :capture, :cancel, :status, :process_variance_refund]

  # POST /api/v1/orders/:order_id/payments/authorize
  def authorize
    ensure_customer_access!(@order)
    return if performed?

    buffer_percentage = (params[:buffer_percentage]&.to_i || 25) / 100.0

    processor = Payment::PaymentProcessor.new
    result = processor.authorize_payment_for_order(@order, buffer_percentage)

    if result[:success]
      render json: {
        success: true,
        message: 'Payment authorized successfully',
        paymentIntentId: result[:payment_intent][:id],
        estimatedTotal: result[:estimated_total],
        preAuthAmount: result[:pre_auth_amount],
        bufferPercentage: buffer_percentage,
        paymentStatus: @order.reload.payment_status
      }
    else
      render json: {
        success: false,
        error: result[:error],
        estimatedTotal: result[:estimated_total],
        preAuthAmount: result[:pre_auth_amount]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/orders/:order_id/payments/capture
  def capture
    ensure_admin!
    return if performed?

    processor = Payment::PaymentProcessor.new
    result = processor.capture_final_payment(@order)

    if result[:success]
      render json: {
        success: true,
        message: 'Payment captured successfully',
        finalTotal: result[:final_total],
        captureAmount: result[:capture_result][:amount] / 100.0,
        paymentStatus: @order.reload.payment_status
      }
    else
      render json: {
        success: false,
        error: result[:error],
        finalTotal: result[:final_total]
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/orders/:order_id/payments/cancel
  def cancel
    ensure_customer_access!(@order)
    return if performed?

    processor = Payment::PaymentProcessor.new
    result = processor.cancel_payment_authorization(@order)

    if result[:success]
      render json: {
        success: true,
        message: 'Payment authorization cancelled',
        paymentStatus: @order.reload.payment_status
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/orders/:order_id/payments/status
  def status
    ensure_order_management!(@order)
    return if performed?

    processor = Payment::PaymentProcessor.new
    payment_status = processor.get_payment_status(@order)

    render json: {
      orderId: @order.id.to_s,
      paymentStatus: payment_status[:payment_status],
      hasPaymentIntent: payment_status[:has_payment_intent],
      amount: payment_status[:amount],
      amountCaptured: payment_status[:amount_captured],
      error: payment_status[:error],
      orderPaymentStatus: @order.payment_status,
      estimatedTotal: @order.estimated_total,
      preAuthAmount: @order.pre_auth_amount,
      finalTotal: @order.final_total,
      paymentIntentId: @order.payment_intent_id
    }
  end

  # POST /api/v1/orders/:order_id/payments/variance_refund
  def process_variance_refund
    ensure_admin!
    return if performed?

    amount = params[:amount].to_f
    reason = params[:reason] || 'variance_refund'

    unless amount > 0
      render json: { errors: ['Refund amount must be greater than 0'] }, status: :bad_request
      return
    end

    processor = Payment::PaymentProcessor.new
    result = processor.process_variance_refund(@order, amount, reason)

    if result[:success]
      render json: {
        success: true,
        message: 'Variance refund processed successfully',
        refundAmount: result[:amount_refunded],
        refundId: result[:refund_result][:id],
        reason: reason
      }
    else
      render json: {
        success: false,
        error: result[:error],
        refundAmount: result[:amount_refunded]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/payments/service_status
  def service_status
    ensure_admin!
    return if performed?

    status = Payment::PaymentService.status

    render json: {
      serviceName: status[:service_name],
      configured: status[:configured],
      environment: status[:environment],
      mockService: status[:mock_service],
      usingMock: Payment::PaymentService.using_mock?
    }
  end

  # POST /api/v1/payments/calculate_pre_auth
  def calculate_pre_auth
    order_total = params[:order_total].to_f
    buffer_percentage = params[:buffer_percentage]&.to_i || 25

    unless order_total > 0
      render json: { errors: ['Order total must be greater than 0'] }, status: :bad_request
      return
    end

    pre_auth_amount = (order_total * (1 + buffer_percentage / 100.0)).round(2)
    buffer_amount = pre_auth_amount - order_total

    render json: {
      orderTotal: order_total,
      bufferPercentage: buffer_percentage,
      bufferAmount: buffer_amount,
      preAuthAmount: pre_auth_amount,
      explanation: "We'll temporarily authorize $#{pre_auth_amount} (#{buffer_percentage}% buffer) to cover potential weight variances. You'll only be charged for the actual items received."
    }
  end

  private

  def set_order
    @order = Order.find(params[:order_id])
  rescue ActiveRecord::RecordNotFound
    render json: { errors: ['Order not found'] }, status: :not_found
  end
end