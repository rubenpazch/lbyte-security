class TokenController < ApplicationController
  before_action :authenticate_user!, only: [ :verify ]

  # GET /token/verify
  # Verifies if the current JWT token is valid and returns user information
  def verify
    if current_user
      render json: {
        valid: true,
        user: {
          id: current_user.id,
          email: current_user.email,
          username: current_user.user_name,  # Fixed: use user_name column
          user_name: current_user.user_name,  # Include both for API compatibility
          full_name: current_user.fullname,   # Use fullname method instead of first_name/last_name
          roles: current_user.roles.pluck(:name),
          permissions: current_user.roles.joins(:permissions).pluck("permissions.name").uniq,
          is_admin: current_user.admin?,  # Use method instead of column
          is_active: current_user.active?,  # Use method instead of column
          status: current_user.status
        },
        message: "Token is valid"
      }, status: :ok
    else
      render json: {
        valid: false,
        message: "Token is invalid or expired"
      }, status: :unauthorized
    end
  end

  # GET /token/info
  # Public endpoint to get token information without authentication (for debugging)
  def info
    token = request.headers["Authorization"]&.split(" ")&.last

    if token.blank?
      render json: {
        error: "No token provided",
        message: "Authorization header with Bearer token is required"
      }, status: :bad_request
      return
    end

    begin
      # Decode without verification to get token info
      decoded_token = JWT.decode(token, nil, false)
      payload = decoded_token.first

      # Check if token is expired
      exp_time = Time.at(payload["exp"]) if payload["exp"]
      is_expired = exp_time && exp_time < Time.current

      render json: {
        token_info: {
          user_id: payload["sub"],
          issued_at: Time.at(payload["iat"]),
          expires_at: exp_time,
          jti: payload["jti"],
          is_expired: is_expired
        },
        message: is_expired ? "Token is expired" : "Token information retrieved"
      }, status: :ok

    rescue JWT::DecodeError => e
      render json: {
        error: "Invalid token format",
        message: e.message
      }, status: :bad_request
    end
  end

  # POST /token/refresh
  # Endpoint to refresh a token (if the current one is still valid)
  def refresh
    if current_user
      # Sign out and sign in again to get a new token
      sign_out(current_user)
      sign_in(current_user)

      render json: {
        message: "Token refreshed successfully",
        user: {
          id: current_user.id,
          email: current_user.email,
          roles: current_user.roles.pluck(:name)
        }
      }, status: :ok
    else
      render json: {
        error: "Cannot refresh token",
        message: "Current token is invalid or expired"
      }, status: :unauthorized
    end
  end

  private

  # Override the default error handling for this controller
  def handle_jwt_decode_error
    render json: {
      valid: false,
      error: "Invalid or expired token",
      message: "The provided JWT token is either invalid, expired, or malformed"
    }, status: :unauthorized
  end
end
