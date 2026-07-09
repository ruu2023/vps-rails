Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root to: ->(env) { [200, { "Content-Type" => "text/plain; charset=utf-8" }, ["Hello World"]] }
end
