Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google_oauth, :client_id),
    Rails.application.credentials.dig(:google_oauth, :client_secret),
    scope: "email,profile"
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.on_failure = proc { |env|
  SessionsController.action(:failure).call(env)
}
