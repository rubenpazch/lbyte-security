#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to setup tenant schemas with tables
# Usage: ruby setup_tenant_schemas.rb

require_relative 'config/environment'

def run_migrations_for_schema(schema_name)
  puts "🔄 Running migrations for schema: #{schema_name}"

  # Switch to the schema
  ActiveRecord::Base.connection.execute("SET search_path TO #{schema_name}")

  # Get migration paths
  migration_paths = ActiveRecord::Migrator.migrations_paths

  # Get all migration files
  migrations = ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).migrations

  # Run each migration in the schema
  migrations.each do |migration|
    begin
      if migration.respond_to?(:migrate)
        migration.migrate(:up)
      else
        migration.new.migrate(:up)
      end
      puts "  ✅ Ran migration: #{migration.name || migration.filename}"
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("already exists")
        puts "  ⚠️  Table already exists in migration: #{migration.name || migration.filename}"
      else
        puts "  ❌ Migration failed: #{migration.name || migration.filename} - #{e.message}"
      end
    rescue => e
      puts "  ❌ Migration error: #{migration.name || migration.filename} - #{e.message}"
    end
  end
end

def setup_tenant_schemas
  puts "🏗️  Setting up tenant schemas with tables..."

  # Get all tenant subdomains
  tenant_schemas = Tenant.active.pluck(:subdomain)

  tenant_schemas.each do |subdomain|
    tenant = Tenant.find_by(subdomain: subdomain)
    puts "\n🏢 Setting up #{tenant.name} (#{subdomain})..."

    begin
      # Ensure schema exists
      ActiveRecord::Base.connection.execute("CREATE SCHEMA IF NOT EXISTS #{subdomain}")

      # Run migrations for this schema
      run_migrations_for_schema(subdomain)

      puts "✅ Schema setup completed for #{subdomain}"

    rescue => e
      puts "❌ Schema setup failed for #{subdomain}: #{e.message}"
    end
  end

  # Switch back to public schema
  ActiveRecord::Base.connection.execute("SET search_path TO public")
  puts "\n✅ All tenant schemas setup completed!"
end

# Run the setup
setup_tenant_schemas
