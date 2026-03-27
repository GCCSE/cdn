if ENV["GITHUB_CLIENT_ID"].present? && ENV["GITHUB_CLIENT_SECRET"].present?
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :github,
      ENV.fetch("GITHUB_CLIENT_ID"),
      ENV.fetch("GITHUB_CLIENT_SECRET"),
      scope: "read:user,user:email"
  end
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.request_validation_phase = OmniAuth::AuthenticityTokenProtection.new(key: :_csrf_token)
