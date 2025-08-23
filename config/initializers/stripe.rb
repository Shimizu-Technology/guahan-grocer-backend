# Stripe configuration for Guahan Grocer

# Initialize Stripe with API keys from environment variables or credentials
Rails.configuration.stripe = {
  publishable_key: ENV["STRIPE_PUBLISHABLE_KEY"] || Rails.application.credentials.dig(:stripe, :publishable_key),
  secret_key: ENV["STRIPE_SECRET_KEY"] || Rails.application.credentials.dig(:stripe, :secret_key),
  webhook_secret: ENV["STRIPE_WEBHOOK_SECRET"] || Rails.application.credentials.dig(:stripe, :webhook_secret)
}

# Set the API key for Stripe requests
Stripe.api_key = Rails.configuration.stripe[:secret_key]

# Set API version for consistency
Stripe.api_version = '2023-10-16'

Rails.logger.info "Stripe configured with keys present: #{Rails.configuration.stripe.transform_values { |v| v.present? ? 'Yes' : 'No' }}"