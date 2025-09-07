# frozen_string_literal: true

# Rails console helper for multitenancy
# Usage: load 'tenant_console_helper.rb' in rails console

class TenantConsoleHelper
  class << self
    # Show current tenant information
    def current
      tenant = TenantHelper.current_tenant
      schema = Thread.current[:current_schema] || "public"

      # Get actual PostgreSQL schema
      actual_schema = ActiveRecord::Base.connection.execute("SELECT current_schema()").first["current_schema"]

      if tenant
        puts "🏢 Current Tenant: #{tenant.name}"
        puts "   Subdomain: #{tenant.subdomain}"
        puts "   Status: #{tenant.status}"
        puts "   Plan: #{tenant.plan}"
        puts "   Thread Schema: #{schema}"
        puts "   Actual DB Schema: #{actual_schema}"
        puts "   Users: #{User.count}"
      else
        puts "🔑 Current Context: Public Schema"
        puts "   Thread Schema: #{schema}"
        puts "   Actual DB Schema: #{actual_schema}"
        puts "   Super Admin Users: #{User.count}"
      end

      tenant
    end    # List all tenants
    def list
      puts "🌍 All Tenants:"
      puts ""

      # Always query tenants from public schema
      current_schema = ActiveRecord::Base.connection.execute("SELECT current_schema()").first["current_schema"]
      original_schema = current_schema
      ActiveRecord::Base.connection.execute("SET search_path TO public") unless current_schema == "public"

      Tenant.active.each do |tenant|
        TenantHelper.with_tenant(tenant.subdomain) do
          user_count = User.count
          puts "🏢 #{tenant.name} (#{tenant.subdomain})"
          puts "   Status: #{tenant.status} | Plan: #{tenant.plan}"
          puts "   Users: #{user_count}"
          puts "   Access: http://#{tenant.subdomain}.localhost:3000"
          puts ""
        end
      end

      # Restore original schema
      ActiveRecord::Base.connection.execute("SET search_path TO #{original_schema}") unless original_schema == "public"
    end

    # Switch to a tenant
    def switch(subdomain)
      # Always query tenants from public schema
      current_schema = ActiveRecord::Base.connection.execute("SELECT current_schema()").first["current_schema"]
      ActiveRecord::Base.connection.execute("SET search_path TO public") unless current_schema == "public"

      tenant = Tenant.find_by(subdomain: subdomain)

      unless tenant
        puts "❌ Tenant '#{subdomain}' not found"
        return false
      end

      TenantHelper.switch_to_schema(tenant.subdomain)
      TenantHelper.current_tenant = tenant
      Thread.current[:current_schema] = tenant.subdomain

      puts "✅ Switched to #{tenant.name} (#{subdomain})"
      current
      tenant
    end

    # Go back to public schema
    def public
      TenantHelper.switch_to_schema("public")
      TenantHelper.current_tenant = nil
      Thread.current[:current_schema] = "public"

      puts "✅ Switched to public schema"
      current
    end

    # Show users in current tenant/schema
    def users
      tenant = TenantHelper.current_tenant
      context = tenant ? "#{tenant.name} (#{tenant.subdomain})" : "Public Schema"

      puts "👥 Users in #{context}:"

      if User.any?
        User.includes(:roles).each do |user|
          roles = user.roles.pluck(:name).join(', ')
          puts "  • #{user.email} (#{roles})"
        end
      else
        puts "  No users found"
      end
    end

    # Execute block in specific tenant context
    def with(subdomain, &block)
      tenant = Tenant.find_by(subdomain: subdomain)

      unless tenant
        puts "❌ Tenant '#{subdomain}' not found"
        return false
      end

      puts "🔄 Executing in #{tenant.name} context..."

      TenantHelper.with_tenant(tenant.subdomain, &block)
    end

    # Seed specific tenant
    def seed(subdomain)
      system("bundle exec rails tenant:seed[#{subdomain}]")
    end

    # Reset specific tenant
    def reset(subdomain)
      system("bundle exec rails tenant:reset[#{subdomain}]")
    end

    # Show help
    def help
      puts "🚀 Tenant Console Helper Commands:"
      puts ""
      puts "TenantConsoleHelper.current      # Show current tenant"
      puts "TenantConsoleHelper.list         # List all tenants"
      puts "TenantConsoleHelper.switch('demo') # Switch to demo tenant"
      puts "TenantConsoleHelper.public       # Switch to public schema"
      puts "TenantConsoleHelper.users        # Show users in current context"
      puts "TenantConsoleHelper.with('acme') { User.count } # Execute in tenant context"
      puts "TenantConsoleHelper.seed('demo') # Seed specific tenant"
      puts "TenantConsoleHelper.reset('demo') # Reset specific tenant"
      puts ""
      puts "🔗 Shortcuts:"
      puts "T = TenantConsoleHelper  # Use T.current, T.list, etc."
      puts ""
      puts "📖 Examples:"
      puts "T.switch('demo')         # Switch to demo tenant"
      puts "User.create!(email: 'test@demo.localhost', password: 'pass123')"
      puts "T.users                  # See users in demo"
      puts "T.public                 # Back to public"
      puts "T.list                   # See all tenants"
    end
  end
end

# Create shortcut
T = TenantConsoleHelper

puts "🚀 Tenant Console Helper loaded!"
puts "Type 'T.help' for available commands"
puts "Type 'T.current' to see current tenant"
puts "Type 'T.list' to see all tenants"
