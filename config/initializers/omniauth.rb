Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV.fetch("GOOGLE_OAUTH_CLIENT_ID", nil),
    ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET", nil),
    scope: "email,profile"
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.on_failure = proc { |env|
  SessionsController.action(:failure).call(env)
}
