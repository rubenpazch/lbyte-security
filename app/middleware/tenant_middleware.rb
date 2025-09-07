# frozen_string_literal: true

# Automatic tenant resolution middleware using pg_multitenant_schemas
class TenantMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Use gem's automatic tenant resolution if available
    if defined?(PgMultitenantSchemas) && PgMultitenantSchemas.respond_to?(:resolve_tenant_from_request)
      tenant = PgMultitenantSchemas.resolve_tenant_from_request(request)
      
      if tenant
        PgMultitenantSchemas.with_tenant(tenant) do
          @app.call(env)
        end
      else
        # Stay in public schema
        @app.call(env)
      end
    else
      # Fallback if gem is not available
      @app.call(env)
    end
  rescue => e
    Rails.logger.error "Tenant middleware error: #{e.message}" if defined?(Rails)
    # Fall back to public schema
    PgMultitenantSchemas.current_tenant = nil if defined?(PgMultitenantSchemas)
    PgMultitenantSchemas.switch_to_schema("public") if defined?(PgMultitenantSchemas) && PgMultitenantSchemas.respond_to?(:switch_to_schema)
    @app.call(env)
  end
end
