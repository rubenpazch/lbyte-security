class SessionsController < Devise::SessionsController
  include TenantHelper

  respond_to :json

  # Tenant resolution callbacks
  before_action :resolve_tenant
  after_action :reset_tenant_context

  # Handle JWT errors in this controller
  rescue_from JWT::DecodeError, with: :handle_jwt_error
  rescue_from JWT::ExpiredSignature, with: :handle_jwt_error
  rescue_from JWT::VerificationError, with: :handle_jwt_error

  private

  def resolve_tenant
    # Use TenantHelper to resolve tenant from request
    tenant = TenantHelper.resolve_tenant_from_request(request)
    switch_to_tenant(tenant)
  rescue => e
    Rails.logger.error "Tenant resolution failed in sessions: #{e.message}"
    if Rails.env.development?
      begin
        switch_to_tenant(nil)  # Fall back to public schema in development
      rescue => fallback_error
        Rails.logger.error "Fallback to public schema failed: #{fallback_error.message}"
        # Continue execution in development even if fallback fails
      end
    else
      raise e  # Re-raise in production
    end
  end

  def reset_tenant_context
    @current_tenant = nil
    TenantHelper.current_tenant = nil
    TenantHelper.switch_to_schema("public")
  rescue => e
    Rails.logger.error "Failed to reset tenant context: #{e.message}"
    # Don't re-raise errors during cleanup
  end

  def switch_to_tenant(tenant)
    instance_variable_set(:@current_tenant, tenant)
    TenantHelper.current_tenant = tenant
    schema_name = tenant&.subdomain || "public"
    TenantHelper.switch_to_schema(schema_name)
  end

  # Make current_tenant available in this controller
  def current_tenant
    @current_tenant
  end

  # Make current_tenant available in views
  helper_method :current_tenant

  def respond_with(resource, _opts = {})
    render "create", status: :ok, formats: [ :json ]
  end

  def respond_to_on_destroy
    if current_user
      render "destroy", status: :no_content, formats: [ :json ]
    else
      render json: { error: "User not found." }, status: :unauthorized
    end
  end

  def respond_to_invalid_login_attempt
    render json: { error: "Invalid Email or password." }, status: :unauthorized
  end

  def handle_jwt_error
    render json: { error: "User not found." }, status: :unauthorized
  end
end
