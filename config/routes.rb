Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "login" => "sessions#new", as: :login
  delete "logout" => "sessions#destroy", as: :logout
  get "auth/google_oauth2/callback" => "sessions#create"
  get "auth/failure" => "sessions#failure"

  namespace :kaikei do
    resource :dashboard, only: :show
    resources :transactions, except: :show
    resources :categories, except: :show
    resources :payment_methods, except: :show
    resources :budgets, only: [ :index, :create, :update, :destroy ]
    resource :exports, only: [ :new, :create ]
  end

  root to: redirect("/kaikei/dashboard")
end
