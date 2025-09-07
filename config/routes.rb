Rails.application.routes.draw do
  # Authentication routes via Devise
  devise_for :users, controllers: { sessions: "sessions", registrations: "registrations" }, defaults: { format: :json }

  # Token verification endpoints
  get "/token/verify", to: "token#verify"
  get "/token/info", to: "token#info"
  post "/token/refresh", to: "token#refresh"

  # User management API endpoints
  namespace :api do
    resources :users do
      member do
        post :toggle_status
        post :assign_role
        delete :remove_role
      end
    end

    # Tenant management endpoints (super admin only)
    resources :tenants, only: [ :index, :show, :create, :update, :destroy ]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Uncomment if you need health check endpoint for load balancers
  # get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
