class ApplicationController < ActionController::API
  include TenantHelper

  # Tenant resolution callbacks
  before_action :resolve_tenant
  after_action :reset_tenant_context

  # Handle JWT decode errors globally
  rescue_from JWT::DecodeError, with: :handle_jwt_decode_error
  rescue_from JWT::ExpiredSignature, with: :handle_jwt_decode_error
  rescue_from JWT::VerificationError, with: :handle_jwt_decode_error

  # Override process_action to ensure tenant context cleanup even on errors
  def process_action(*args)
    super
  rescue => e
    # Ensure cleanup happens even when action fails
    reset_tenant_context_safe
    raise e
  end

  private

  def resolve_tenant
    # Use TenantHelper to resolve tenant from request
    tenant = TenantHelper.resolve_tenant_from_request(request)
    switch_to_tenant(tenant)
  rescue => e
    Rails.logger.error "Tenant resolution failed: #{e.message}"
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

  def reset_tenant_context_safe
    reset_tenant_context
  end

  def switch_to_tenant(tenant)
    instance_variable_set(:@current_tenant, tenant)
    TenantHelper.current_tenant = tenant
    schema_name = tenant&.subdomain || "public"
    TenantHelper.switch_to_schema(schema_name)
  end

  # Make current_tenant available in controllers
  def current_tenant
    @current_tenant
  end

  # Make current_tenant available in views
  helper_method :current_tenant

  def handle_jwt_decode_error
    render json: { error: "Invalid or expired token." }, status: :unauthorized
  end

  def handle_tenant_not_found(exception)
    render json: {
      error: "Tenant not found",
      message: exception.message
    }, status: :not_found
  end

  def handle_schema_not_found(exception)
    render json: {
      error: "Schema not found",
      message: exception.message
    }, status: :unprocessable_content
  end
end
