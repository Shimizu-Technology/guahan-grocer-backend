# Payment service factory that returns the appropriate payment implementation
# This allows us to easily switch between mock and real payment services
class Payment::PaymentService
  class << self
    # Get the current payment service instance
    # @return [Payment::PaymentServiceInterface] The configured payment service
    def current
      @current_service ||= build_service
    end
    
    # Force reload of the payment service (useful for testing)
    def reload!
      @current_service = nil
      current
    end
    
    # Check if we're using the mock payment service
    # @return [Boolean] True if using mock service
    def using_mock?
      current.is_a?(Payment::MockPaymentService)
    end
    
    # Check if we're using a real payment service
    # @return [Boolean] True if using real payment service
    def using_real_payment?
      !using_mock?
    end
    
    # Get service status and configuration info
    # @return [Hash] Service status information
    def status
      service = current
      {
        service_name: service.service_name,
        configured: service.configured?,
        environment: Rails.env,
        mock_service: using_mock?
      }
    end
    
    private
    
    def build_service
      if should_use_mock_service?
        Payment::MockPaymentService.new
      else
        build_real_payment_service
      end
    end
    
    def should_use_mock_service?
      # Use mock service in development and test environments
      return true if Rails.env.development? || Rails.env.test?
      
      # Use mock service if no real payment service is configured
      return true unless stripe_configured?
      
      # Use mock service if explicitly requested
      return true if ENV['USE_MOCK_PAYMENTS'] == 'true'
      
      false
    end
    
    def stripe_configured?
      # Check if Stripe is properly configured
      stripe_secret_key.present? && stripe_publishable_key.present?
    end
    
    def stripe_secret_key
      ENV['STRIPE_SECRET_KEY'] || Rails.application.credentials.dig(:stripe, :secret_key)
    end
    
    def stripe_publishable_key
      ENV['STRIPE_PUBLISHABLE_KEY'] || Rails.application.credentials.dig(:stripe, :publishable_key)
    end
    
    def build_real_payment_service
      if stripe_configured?
        Payment::StripePaymentService.new
      else
        raise ConfigurationError, "No payment service configured. Please configure Stripe or set USE_MOCK_PAYMENTS=true"
      end
    end
  end
  
  # Custom error for payment service configuration issues
  class ConfigurationError < StandardError; end
end