# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Development: Allow localhost and Expo development URLs
    origins(
      'http://localhost:3000',    # React Native web
      'http://localhost:8081',    # Expo development server
      'http://localhost:19006',   # Expo web
      /\Ahttp:\/\/localhost:\d+\z/, # Any localhost port
      /\Ahttp:\/\/192\.168\.\d+\.\d+:\d+\z/, # Local network IPs for mobile testing
      /\Aexp:\/\/192\.168\.\d+\.\d+:\d+\z/   # Expo development URLs
    )

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false
  end
  
  # Production: Add your production domains here
  if Rails.env.production?
    allow do
      origins(
        'https://guahan-grocer.expo.app',
        'https://guahan-grocer.netlify.app'
      )
      
      resource "*",
        headers: :any,
        methods: [:get, :post, :put, :patch, :delete, :options, :head],
        credentials: false
    end
  end
end
