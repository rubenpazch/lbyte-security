class RegistrationsController < Devise::RegistrationsController
  respond_to :json

  # Override create to prevent automatic sign-in
  def create
    build_resource(sign_up_params)

    if resource.save
      yield resource if block_given?
      if resource.active_for_authentication?
        # Don't sign in for API-only apps
        render "create", formats: [ :json ]
      else
        render "create_inactive", formats: [ :json ]
      end
    else
      clean_up_passwords resource
      render json: {
        status: { message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}" },
        errors: resource.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  private

  def respond_with(resource, _opts = {})
    if resource.persisted?
      render "create", formats: [ :json ]
    else
      render json: {
        status: { message: "User couldn't be created successfully. #{resource.errors.full_messages.to_sentence}" },
        errors: resource.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  def respond_with_navigational(*args, &block)
    respond_with(*args, &block)
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :user_name, :status, :phone, :occupation, :company_name, :location, :flag, :activity, :pic, :avatar, :user_gmail)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :user_name, :status, :phone, :occupation, :company_name, :location, :flag, :activity, :pic, :avatar, :user_gmail)
  end
end
