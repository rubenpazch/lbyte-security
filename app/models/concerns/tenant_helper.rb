# frozen_string_literal: true

module TenantHelper
  extend ActiveSupport::Concern

  # Delegate to gem's Context for thread-safe tenant management
  def self.current_tenant
    PgMultitenantSchemas.current_tenant
  end

  def self.current_tenant=(tenant)
    PgMultitenantSchemas.current_tenant = tenant
  end

  def self.current_schema
    PgMultitenantSchemas.current_schema
  end

  def self.current_schema=(schema_name)
    PgMultitenantSchemas.current_schema = schema_name
  end

  # Switch to a specific tenant and execute block using gem's API
  def self.with_tenant(tenant_or_schema, &block)
    PgMultitenantSchemas.with_tenant(tenant_or_schema, &block)
  end

  # Switch to specific schema using gem's API with Rails 8 compatibility fix
  def self.switch_to_schema(schema_name)
    schema_name = "public" if schema_name.blank?
    
    # Use gem's SchemaSwitcher with the correct API (version 0.2.0 only expects schema_name)
    PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema_name)
    PgMultitenantSchemas.current_schema = schema_name
  rescue NoMethodError => e
    if e.message.include?("private method 'exec'")
      # Rails 8 compatibility - use execute instead of exec
      quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
      connection.execute("SET search_path TO #{quoted_schema};")
      PgMultitenantSchemas.current_schema = schema_name
    else
      raise e
    end
  end

  # Create new tenant schema using gem's API with Rails 8 compatibility
  def self.create_tenant_schema(tenant_or_schema)
    schema_name = tenant_or_schema.is_a?(Tenant) ? tenant_or_schema.subdomain : tenant_or_schema
    # Use gem's create_schema with the correct API (version 0.2.0 only expects schema_name)
    PgMultitenantSchemas::SchemaSwitcher.create_schema(schema_name)
  rescue NoMethodError => e
    if e.message.include?("private method 'exec'")
      # Rails 8 compatibility - use execute instead of exec
      quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
      connection.execute("CREATE SCHEMA IF NOT EXISTS #{quoted_schema};")
    else
      raise e
    end
  end

  # Drop tenant schema using gem's API with Rails 8 compatibility
  def self.drop_tenant_schema(tenant_or_schema)
    schema_name = tenant_or_schema.is_a?(Tenant) ? tenant_or_schema.subdomain : tenant_or_schema
    # Use gem's drop_schema with the correct API (version 0.2.0 only expects schema_name)
    PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema_name)
  rescue NoMethodError => e
    if e.message.include?("private method 'exec'")
      # Rails 8 compatibility - use execute instead of exec
      quoted_schema = "\"#{schema_name.gsub('"', '""')}\""
      connection.execute("DROP SCHEMA IF EXISTS #{quoted_schema} CASCADE;")
    else
      raise e
    end
  end

  # Extract subdomain from host using gem's API
  def self.extract_subdomain(host)
    PgMultitenantSchemas.extract_subdomain(host)
  end

  # Find tenant by subdomain using gem's API
  def self.find_tenant_by_subdomain(subdomain)
    PgMultitenantSchemas.find_tenant_by_subdomain(subdomain)
  end

  # Resolve tenant from request using gem's API
  def self.resolve_tenant_from_request(request)
    PgMultitenantSchemas.resolve_tenant_from_request(request)
  end

  included do
    # Instance methods available in controllers
    def current_tenant
      @current_tenant
    end

    def switch_to_tenant(tenant)
      @current_tenant = tenant
      TenantHelper.current_tenant = tenant
      schema_name = tenant&.subdomain || "public"
      TenantHelper.switch_to_schema(schema_name)
    end

    def resolve_tenant
      tenant = TenantHelper.resolve_tenant_from_request(request)
      switch_to_tenant(tenant)
    rescue => e
      Rails.logger.error "Tenant resolution failed: #{e.message}"
      if Rails.env.development?
        switch_to_tenant(nil)  # Fall back to public schema in development
      else
        raise e
      end
    end

    def reset_tenant_context
      @current_tenant = nil
      TenantHelper.current_tenant = nil
      TenantHelper.switch_to_schema("public")
    end
  end
end
