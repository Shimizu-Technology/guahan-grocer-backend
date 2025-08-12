Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Sidekiq Web UI for monitoring background jobs
  require 'sidekiq/web'
  
  # Secure Sidekiq Web UI in production with HTTP Basic Auth
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      # Use environment variables for admin credentials
      username == ENV.fetch('SIDEKIQ_USERNAME', 'admin') && 
      password == ENV.fetch('SIDEKIQ_PASSWORD', 'change_me_in_production')
    end
  end
  
  mount Sidekiq::Web => '/sidekiq'

  # API v1 routes
  namespace :api do
    namespace :v1 do
      # Address management
      resources :addresses do
        member do
          put :make_default
        end
      end
      
      # Categories and Units management
      resources :categories, only: [:index, :create, :show, :update, :destroy]
      resources :units, only: [:index, :create, :show, :update, :destroy]
      # Authentication routes
      namespace :auth do
        post :login
        post :register
        get :me
        delete :logout
        put :toggle_online
      end

      # Core resource routes
      resources :products do
        collection do
          get :featured
        end
        member do
          post :upload_image, to: 'products#upload_image'
          delete :delete_image, to: 'products#delete_image'
        end
      end
      
      resources :orders do
        member do
          put :assign_driver
          put :status, to: 'orders#update_status'
          put :accept, to: 'orders#accept_order'
          post :receipt, to: 'orders#upload_receipt'
          get :timeline
        end
        collection do
            get :available
            get :active
            post :calculate_delivery_fee
          end
        end

      resources :order_items, only: [] do
        member do
          put :status, to: 'order_items#update_status'
          put :found_quantity, to: 'order_items#update_found_quantity'
          put :substitute, to: 'order_items#substitute'
        end
      end

      # User management
      resources :users, only: [:index, :show, :create, :update, :destroy]
      get 'drivers/available', to: 'users#available_drivers'

      # Favorites
      resources :favorites, only: [:index, :create] do
        collection do
          delete ':product_id', action: :destroy, as: :remove
        end
      end

      # Driver stats
      resources :driver_stats, only: [:index, :show], param: :date

      # Vehicle management
      resources :vehicles

      # Stores management
      resources :stores do
        member do
          put :toggle_active
        end
      end

      # Admin routes
      namespace :admin do
        get :dashboard
        get :sms_report
      end
    end
  end

  # Root path
  root "rails/health#show"
end
