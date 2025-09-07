# frozen_string_literal: true

namespace :tenant do
  desc "Run migrations for all tenant schemas"
  task migrate_all: :environment do
    puts "🔄 Running migrations for all tenant schemas..."

    Tenant.active.each do |tenant|
      puts "\n🏢 Migrating #{tenant.name} (#{tenant.subdomain})..."

      begin
        # Switch to tenant schema
        TenantHelper.switch_to_schema(tenant.subdomain)

        # Run migrations
        ActiveRecord::Base.connection.migration_context.migrate

        puts "✅ Migrations completed for #{tenant.subdomain}"
      rescue => e
        puts "❌ Migration failed for #{tenant.subdomain}: #{e.message}"
      end
    end

    # Switch back to public
    TenantHelper.switch_to_schema("public")
    puts "\n✅ All tenant migrations completed!"
  end

  desc "Run migrations for a specific tenant"
  task :migrate, [ :subdomain ] => :environment do |_task, args|
    subdomain = args[:subdomain]

    if subdomain.blank?
      puts "❌ Please provide a tenant subdomain: rails tenant:migrate[demo]"
      exit 1
    end

    tenant = Tenant.find_by(subdomain: subdomain)
    unless tenant
      puts "❌ Tenant '#{subdomain}' not found"
      exit 1
    end

    puts "🔄 Running migrations for #{tenant.name} (#{subdomain})..."

    begin
      # Switch to tenant schema
      TenantHelper.switch_to_schema(subdomain)

      # Run migrations
      ActiveRecord::Base.connection.migration_context.migrate

      puts "✅ Migrations completed for #{subdomain}"
    rescue => e
      puts "❌ Migration failed for #{subdomain}: #{e.message}"
    ensure
      # Switch back to public
      TenantHelper.switch_to_schema("public")
    end
  end

  desc "Create schema and run migrations for new tenant"
  task :setup, [ :subdomain ] => :environment do |_task, args|
    subdomain = args[:subdomain]

    if subdomain.blank?
      puts "❌ Please provide a tenant subdomain: rails tenant:setup[newcompany]"
      exit 1
    end

    puts "🏗️  Setting up new tenant schema: #{subdomain}"

    begin
      # Create schema
      TenantHelper.create_tenant_schema(subdomain)

      # Run migrations
      TenantHelper.switch_to_schema(subdomain)
      ActiveRecord::Base.connection.migration_context.migrate

      puts "✅ Schema and migrations completed for #{subdomain}"

      # Seed basic roles and permissions
      TenantHelper.with_tenant(subdomain) do
        load Rails.root.join("db", "seeds", "roles.rb")
        load Rails.root.join("db", "seeds", "permissions.rb")
        puts "✅ Basic roles and permissions seeded"
      end

    rescue => e
      puts "❌ Setup failed for #{subdomain}: #{e.message}"
    ensure
      TenantHelper.switch_to_schema("public")
    end
  end

  desc "Show database schemas"
  task schemas: :environment do
    puts "📊 Database Schemas:"

    schemas = ActiveRecord::Base.connection.execute(
      "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast_temp_1') ORDER BY schema_name"
    ).to_a

    schemas.each do |row|
      schema_name = row["schema_name"]

      # Check if it has tables
      TenantHelper.switch_to_schema(schema_name)
      table_count = ActiveRecord::Base.connection.tables.count

      if schema_name == "public"
        puts "🔑 #{schema_name} (#{table_count} tables) - Super Admin schema"
      else
        tenant = Tenant.find_by(subdomain: schema_name)
        if tenant
          puts "🏢 #{schema_name} (#{table_count} tables) - #{tenant.name}"
        else
          puts "❓ #{schema_name} (#{table_count} tables) - Unknown tenant"
        end
      end
    end

    TenantHelper.switch_to_schema("public")
  end
end
