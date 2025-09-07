# frozen_string_literal: true

namespace :tenant do
  desc "Seed a specific tenant with sample data"
  task :seed, [ :subdomain ] => :environment do |_task, args|
    subdomain = args[:subdomain]

    if subdomain.blank?
      puts "❌ Please provide a tenant subdomain: rails tenant:seed[demo]"
      exit 1
    end

    tenant = Tenant.find_by(subdomain: subdomain)
    unless tenant
      puts "❌ Tenant '#{subdomain}' not found. Available tenants:"
      Tenant.active.pluck(:subdomain, :name).each do |sub, name|
        puts "  • #{sub} (#{name})"
      end
      exit 1
    end

    puts "🏢 Seeding tenant: #{tenant.name} (#{subdomain})"

    TenantHelper.with_tenant(tenant.subdomain) do
      # Clear existing data
      puts "🧹 Cleaning existing data in #{tenant.name}..."
      User.destroy_all
      JwtDenylist.destroy_all

      # Load roles and permissions for this tenant
      load Rails.root.join("db", "seeds", "roles.rb")
      load Rails.root.join("db", "seeds", "permissions.rb")

      # Create tenant-specific users
      case subdomain
      when "demo"
        seed_demo_users
      when "acme"
        seed_acme_users
      when "beta"
        seed_beta_users
      when "gamma"
        seed_gamma_users
      else
        seed_generic_users(tenant)
      end

      puts "✅ #{tenant.name} seeded successfully!"
      puts "📊 Total users: #{User.count}"
      puts "🔗 Access at: http://#{subdomain}.localhost:3000"
    end
  end

  desc "Seed all tenants with sample data"
  task seed_all: :environment do
    puts "🌍 Seeding all active tenants..."

    Tenant.active.each do |tenant|
      Rake::Task["tenant:seed"].reenable
      Rake::Task["tenant:seed"].invoke(tenant.subdomain)
      puts ""
    end

    puts "🎉 All tenants seeded successfully!"
  end

  desc "Show tenant information and user counts"
  task info: :environment do
    puts "🏢 Tenant Information:"
    puts ""

    # Public schema info
    TenantHelper.switch_to_schema("public")
    puts "🔑 Public Schema (Super Admins):"
    puts "  Users: #{User.count}"
    User.joins(:roles).group("roles.name").count.each do |role, count|
      puts "    • #{role}: #{count}"
    end
    puts ""

    # Each tenant info
    Tenant.active.each do |tenant|
      TenantHelper.with_tenant(tenant.subdomain) do
        puts "🏢 #{tenant.name} (#{tenant.subdomain}):"
        puts "  Status: #{tenant.status} | Plan: #{tenant.plan}"
        puts "  Users: #{User.count}"

        if User.any?
          User.joins(:roles).group("roles.name").count.each do |role, count|
            puts "    • #{role}: #{count}"
          end
        end

        puts "  Access: http://#{tenant.subdomain}.localhost:3000"
        puts ""
      end
    end
  end

  desc "Reset a specific tenant (drops schema and recreates)"
  task :reset, [ :subdomain ] => :environment do |_task, args|
    subdomain = args[:subdomain]

    if subdomain.blank?
      puts "❌ Please provide a tenant subdomain: rails tenant:reset[demo]"
      exit 1
    end

    tenant = Tenant.find_by(subdomain: subdomain)
    unless tenant
      puts "❌ Tenant '#{subdomain}' not found"
      exit 1
    end

    puts "🔄 Resetting tenant: #{tenant.name} (#{subdomain})"

    # Drop and recreate schema
    TenantHelper.drop_tenant_schema(subdomain)
    TenantHelper.create_tenant_schema(subdomain)

    # Run migrations for the tenant
    TenantHelper.with_tenant(subdomain) do
      ActiveRecord::Base.connection.execute("SET search_path TO #{subdomain}")
      ActiveRecord::Migrator.migrate(ActiveRecord::Migrator.migrations_paths)
    end

    # Seed the tenant
    Rake::Task["tenant:seed"].reenable
    Rake::Task["tenant:seed"].invoke(subdomain)

    puts "✅ #{tenant.name} reset and seeded successfully!"
  end

  private

  def seed_demo_users
    users = [
      {
        email: "admin@demo.localhost",
        username: "demo_admin",
        first_name: "Demo",
        last_name: "Administrator",
        role_name: "Super Admin",
        password: "AdminDemo123!"
      },
      {
        email: "manager@demo.localhost",
        username: "demo_manager",
        first_name: "John",
        last_name: "Manager",
        role_name: "Manager",
        password: "ManagerDemo123!"
      },
      {
        email: "user@demo.localhost",
        username: "demo_user",
        first_name: "Alice",
        last_name: "Smith",
        role_name: "User",
        password: "UserDemo123!"
      }
    ]

    create_tenant_users(users, "Demo Organization")
  end

  def seed_acme_users
    users = [
      {
        email: "admin@acme.localhost",
        username: "acme_admin",
        first_name: "Bob",
        last_name: "Wilson",
        role_name: "Super Admin",
        password: "AdminAcme123!"
      },
      {
        email: "finance@acme.localhost",
        username: "acme_finance",
        first_name: "Carol",
        last_name: "Johnson",
        role_name: "Finance Manager",
        password: "FinanceAcme123!"
      },
      {
        email: "developer@acme.localhost",
        username: "acme_dev",
        first_name: "David",
        last_name: "Brown",
        role_name: "User",
        password: "DevAcme123!"
      }
    ]

    create_tenant_users(users, "Acme Corporation")
  end

  def seed_beta_users
    users = [
      {
        email: "admin@beta.localhost",
        username: "beta_admin",
        first_name: "Frank",
        last_name: "Miller",
        role_name: "Super Admin",
        password: "AdminBeta123!"
      },
      {
        email: "hr@beta.localhost",
        username: "beta_hr",
        first_name: "Grace",
        last_name: "Taylor",
        role_name: "Manager",
        password: "HRBeta123!"
      }
    ]

    create_tenant_users(users, "Beta Industries")
  end

  def seed_gamma_users
    users = [
      {
        email: "trial@gamma.localhost",
        username: "gamma_trial",
        first_name: "Isabel",
        last_name: "Garcia",
        role_name: "Super Admin",
        password: "TrialGamma123!"
      }
    ]

    create_tenant_users(users, "Gamma Solutions")
  end

  def seed_generic_users(tenant)
    users = [
      {
        email: "admin@#{tenant.subdomain}.localhost",
        username: "#{tenant.subdomain}_admin",
        first_name: "Admin",
        last_name: "User",
        role_name: "Super Admin",
        password: "Admin#{tenant.subdomain.capitalize}123!"
      },
      {
        email: "user@#{tenant.subdomain}.localhost",
        username: "#{tenant.subdomain}_user",
        first_name: "Regular",
        last_name: "User",
        role_name: "User",
        password: "User#{tenant.subdomain.capitalize}123!"
      }
    ]

    create_tenant_users(users, tenant.name)
  end

  def create_tenant_users(users_data, company_name)
    users_data.each do |user_attrs|
      role_name = user_attrs.delete(:role_name)

      # Set default attributes
      user_attrs.merge!(
        password_confirmation: user_attrs[:password],
        email_verified: true,
        is_active: true,
        status: "active",
        language: "en",
        company_name: company_name,
        activity: "Created in #{company_name} tenant seeds"
      )

      user = User.find_or_create_by(email: user_attrs[:email]) do |u|
        u.assign_attributes(user_attrs)
      end

      if user.persisted?
        # Assign role
        if role_name
          role = Role.find_by(name: role_name)
          if role
            user.roles << role unless user.roles.include?(role)
            puts "  ✅ Created user: #{user.email} (#{role_name})"
          else
            puts "  ⚠️  Role '#{role_name}' not found for user: #{user.email}"
          end
        end
      else
        puts "  ❌ Failed to create user: #{user_attrs[:email]} - #{user.errors.full_messages.join(', ')}"
      end
    end
  end
end
