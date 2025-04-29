class SessionsController < Devise::SessionsController
  respond_to :json

  private

  def respond_with(resource, _opts = {})
    render json: { message: "Logged in successfully.", user: resource }, status: :ok
  end

  def respond_to_on_destroy
    if current_user
      render json: { message: "Logged out successfully." }, status: :no_content
    else
      render json: { error: "User not found." }, status: :unauthorized
    end
  end

  def respond_to_invalid_login_attempt
    render json: { error: "Invalid Email or password." }, status: :unauthorized
  end
end
