Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API v1 routes
  namespace :api do
    namespace :v1 do
      # Authentication routes
      namespace :auth do
        post :login
        post :register
        get :me
        delete :logout
      end

      # Core resource routes
      resources :products do
        member do
          post :upload_image, to: 'products#upload_image'
          delete :delete_image, to: 'products#delete_image'
        end
      end
      
      resources :orders do
        member do
          put :assign_driver
          put :status, to: 'orders#update_status'
        end
        collection do
          get :available
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
      resources :users, only: [:index, :show, :update]
      get 'drivers/available', to: 'users#available_drivers'

      # Favorites
      resources :favorites, only: [:index, :create] do
        collection do
          delete ':product_id', action: :destroy, as: :remove
        end
      end

      # Driver stats
      resources :driver_stats, only: [:index, :show], param: :date

      # Admin routes
      namespace :admin do
        get :dashboard
      end
    end
  end

  # Root path
  root "rails/health#show"
end
