# Support methods for authentication testing

module AuthenticationHelpers
  # Helper method to sign in a user and return the JWT token
  def sign_in_user(user)
    post "/users/sign_in", params: { user: { email: user.email, password: user.password } }
    response.headers["Authorization"]
  end

  # Helper method to create a user and sign them in
  def create_and_sign_in_user(user_type = :user)
    user = create(user_type)
    token = sign_in_user(user)
    { user: user, token: token }
  end

  # Helper method to get JWT payload without verification (for testing)
  def decode_jwt_payload(token)
    token_without_bearer = token.gsub("Bearer ", "")
    payload = JSON.parse(Base64.decode64(token_without_bearer.split(".")[1]))
    payload
  rescue => e
    nil
  end

  # Helper to create valid user params
  def valid_user_params_for(user)
    { user: { email: user.email, password: user.password } }
  end

  # Helper to create invalid user params
  def invalid_user_params
    { user: { email: "invalid@example.com", password: "wrongpassword" } }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
