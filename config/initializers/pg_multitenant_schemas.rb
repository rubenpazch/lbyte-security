# frozen_string_literal: true

# Configure pg_multitenant_schemas gem - with defensive loading
begin
  if defined?(PgMultitenantSchemas)
    PgMultitenantSchemas.configure do |config|
      config.connection_class = 'ApplicationRecord'
      config.tenant_model_class = 'Tenant'
      config.default_schema = "public"
      config.development_fallback = true
      config.auto_create_schemas = false  # Don't auto-create since we've set them up manually
      
      # Additional configuration options (if supported by gem)
      config.parallel_migrations = true if config.respond_to?(:parallel_migrations)
      config.cache_tenant_lookups = true if config.respond_to?(:cache_tenant_lookups)
      config.tenant_not_found_handler = ->(subdomain) { 
        Rails.logger.warn "Tenant not found for subdomain: #{subdomain}"
        nil
      } if config.respond_to?(:tenant_not_found_handler)
      
      # Custom schema naming if available
      config.schema_naming_strategy = :subdomain if config.respond_to?(:schema_naming_strategy)
    end

    Rails.application.config.after_initialize do
      if defined?(PgMultitenantSchemas)
        Rails.logger.info "PgMultitenantSchemas gem configured and initialized successfully"
      end
    end
  end
rescue => e
  Rails.logger.error "Failed to configure PgMultitenantSchemas: #{e.message}"
  # Continue without the gem if there's an issue
end
