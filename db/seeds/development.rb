# Development environment specific seeds
# This file contains sample data for development and testing
# Note: Permissions and Roles are loaded from separate files first

puts "👥 Creating users for development environment with multitenancy..."

# First, ensure tenants exist and seed tenants if needed
load Rails.root.join('db', 'seeds', 'tenants.rb')

# Clear existing users in public schema and all tenant schemas
puts "🧹 Cleaning existing users across all tenants..."

# Clean public schema
TenantHelper.switch_to_schema("public")
User.destroy_all
JwtDenylist.destroy_all

# Clean all tenant schemas
Tenant.active.each do |tenant|
  TenantHelper.with_tenant(tenant.subdomain) do
    User.destroy_all
    JwtDenylist.destroy_all
    puts "  🧹 Cleaned users in #{tenant.name} (#{tenant.subdomain})"
  end
end

puts "👥 Creating sample users per tenant..."

# Define tenant-specific user data
tenant_users_data = {
  "demo" => [
    {
      email: "admin@demo.localhost",
      password: "AdminDemo123!",
      password_confirmation: "AdminDemo123!",
      username: "demo_admin",
      first_name: "Demo",
      last_name: "Administrator",
      role_name: "Super Admin",
      is_admin: true,
      location: "San Francisco, USA",
      flag: "us",
      occupation: "System Administrator",
      company_name: "Demo Organization",
      avatar: "300-1.png",
      user_name: "Demo Administrator",
      user_gmail: "admin@demo.localhost",
      phone: "+1-555-1001"
    },
    {
      email: "manager@demo.localhost",
      password: "ManagerDemo123!",
      password_confirmation: "ManagerDemo123!",
      username: "demo_manager",
      first_name: "John",
      last_name: "Manager",
      role_name: "Manager",
      location: "New York, USA",
      flag: "us",
      occupation: "Operations Manager",
      company_name: "Demo Organization",
      avatar: "300-2.png",
      user_name: "John Manager",
      user_gmail: "john.manager@demo.localhost",
      phone: "+1-555-1002"
    },
    {
      email: "user@demo.localhost",
      password: "UserDemo123!",
      password_confirmation: "UserDemo123!",
      username: "demo_user",
      first_name: "Alice",
      last_name: "Smith",
      role_name: "User",
      location: "Chicago, USA",
      flag: "us",
      occupation: "Software Engineer",
      company_name: "Demo Organization",
      avatar: "300-3.png",
      user_name: "Alice Smith",
      user_gmail: "alice.smith@demo.localhost",
      phone: "+1-555-1003"
    }
  ],
  "acme" => [
    {
      email: "admin@acme.localhost",
      password: "AdminAcme123!",
      password_confirmation: "AdminAcme123!",
      username: "acme_admin",
      first_name: "Bob",
      last_name: "Wilson",
      role_name: "Super Admin",
      is_admin: true,
      location: "Los Angeles, USA",
      flag: "us",
      occupation: "Chief Technology Officer",
      company_name: "Acme Corporation",
      avatar: "300-4.png",
      user_name: "Bob Wilson",
      user_gmail: "bob.wilson@acme.localhost",
      phone: "+1-555-2001"
    },
    {
      email: "finance@acme.localhost",
      password: "FinanceAcme123!",
      password_confirmation: "FinanceAcme123!",
      username: "acme_finance",
      first_name: "Carol",
      last_name: "Johnson",
      role_name: "Finance Manager",
      location: "Dallas, USA",
      flag: "us",
      occupation: "Finance Manager",
      company_name: "Acme Corporation",
      avatar: "300-5.png",
      user_name: "Carol Johnson",
      user_gmail: "carol.johnson@acme.localhost",
      phone: "+1-555-2002"
    },
    {
      email: "developer@acme.localhost",
      password: "DevAcme123!",
      password_confirmation: "DevAcme123!",
      username: "acme_dev",
      first_name: "David",
      last_name: "Brown",
      role_name: "User",
      location: "Austin, USA",
      flag: "us",
      occupation: "Full Stack Developer",
      company_name: "Acme Corporation",
      avatar: "300-6.png",
      user_name: "David Brown",
      user_gmail: "david.brown@acme.localhost",
      phone: "+1-555-2003"
    },
    {
      email: "sales@acme.localhost",
      password: "SalesAcme123!",
      password_confirmation: "SalesAcme123!",
      username: "acme_sales",
      first_name: "Emma",
      last_name: "Davis",
      role_name: "Manager",
      location: "Miami, USA",
      flag: "us",
      occupation: "Sales Manager",
      company_name: "Acme Corporation",
      avatar: "300-7.png",
      user_name: "Emma Davis",
      user_gmail: "emma.davis@acme.localhost",
      phone: "+1-555-2004"
    }
  ],
  "beta" => [
    {
      email: "admin@beta.localhost",
      password: "AdminBeta123!",
      password_confirmation: "AdminBeta123!",
      username: "beta_admin",
      first_name: "Frank",
      last_name: "Miller",
      role_name: "Super Admin",
      is_admin: true,
      location: "London, UK",
      flag: "gb",
      occupation: "Managing Director",
      company_name: "Beta Industries",
      avatar: "300-8.png",
      user_name: "Frank Miller",
      user_gmail: "frank.miller@beta.localhost",
      phone: "+44-555-3001"
    },
    {
      email: "hr@beta.localhost",
      password: "HRBeta123!",
      password_confirmation: "HRBeta123!",
      username: "beta_hr",
      first_name: "Grace",
      last_name: "Taylor",
      role_name: "Manager",
      location: "Manchester, UK",
      flag: "gb",
      occupation: "HR Manager",
      company_name: "Beta Industries",
      avatar: "300-9.png",
      user_name: "Grace Taylor",
      user_gmail: "grace.taylor@beta.localhost",
      phone: "+44-555-3002"
    },
    {
      email: "analyst@beta.localhost",
      password: "AnalystBeta123!",
      password_confirmation: "AnalystBeta123!",
      username: "beta_analyst",
      first_name: "Henry",
      last_name: "Wilson",
      role_name: "User",
      location: "Edinburgh, UK",
      flag: "gb",
      occupation: "Business Analyst",
      company_name: "Beta Industries",
      avatar: "300-10.png",
      user_name: "Henry Wilson",
      user_gmail: "henry.wilson@beta.localhost",
      phone: "+44-555-3003"
    }
  ],
  "gamma" => [
    {
      email: "trial@gamma.localhost",
      password: "TrialGamma123!",
      password_confirmation: "TrialGamma123!",
      username: "gamma_trial",
      first_name: "Isabel",
      last_name: "Garcia",
      role_name: "Super Admin",
      is_admin: true,
      location: "Barcelona, Spain",
      flag: "es",
      occupation: "CEO",
      company_name: "Gamma Solutions",
      avatar: "300-11.png",
      user_name: "Isabel Garcia",
      user_gmail: "isabel.garcia@gamma.localhost",
      phone: "+34-555-4001"
    },
    {
      email: "support@gamma.localhost",
      password: "SupportGamma123!",
      password_confirmation: "SupportGamma123!",
      username: "gamma_support",
      first_name: "Jack",
      last_name: "Rodriguez",
      role_name: "User",
      location: "Madrid, Spain",
      flag: "es",
      occupation: "Customer Support",
      company_name: "Gamma Solutions",
      avatar: "300-12.png",
      user_name: "Jack Rodriguez",
      user_gmail: "jack.rodriguez@gamma.localhost",
      phone: "+34-555-4002"
    }
  ]
}

# Super Admin users (created in public schema, can access all tenants)
super_admin_users = [
  {
    email: "superadmin@lbytesecurity.com",
    password: "SuperSecure123!",
    password_confirmation: "SuperSecure123!",
    username: "superadmin",
    first_name: "Super",
    last_name: "Administrator",
    role_name: "Super Admin",
    is_admin: true,
    location: "San Francisco, USA",
    flag: "us",
    occupation: "Chief Technology Officer",
    company_name: "LByte Security",
    avatar: "300-1.png",
    user_name: "Super Administrator",
    user_gmail: "superadmin@lbytesecurity.com",
    phone: "+1-555-0001"
  },
  {
    email: "platform@lbytesecurity.com",
    password: "PlatformSecure123!",
    password_confirmation: "PlatformSecure123!",
    username: "platform_admin",
    first_name: "Platform",
    last_name: "Admin",
    role_name: "Super Admin",
    is_admin: true,
    location: "Seattle, USA",
    flag: "us",
    occupation: "Platform Administrator",
    company_name: "LByte Security",
    avatar: "300-13.png",
    user_name: "Platform Admin",
    user_gmail: "platform@lbytesecurity.com",
    phone: "+1-555-0013"
  }
]

# Create Super Admin users in public schema
puts "\n🔑 Creating Super Admin users in public schema..."
TenantHelper.switch_to_schema("public")

super_admin_users.each do |user_attrs|
  role_name = user_attrs.delete(:role_name)

  user = User.find_or_create_by(email: user_attrs[:email]) do |u|
    u.assign_attributes(user_attrs)
    u.email_verified = true
    u.is_active = true
    u.status = 'active'
    u.language = 'en'
    u.activity = "Created as Super Admin in development seeds"
  end

  if user.persisted?
    # Assign Super Admin role
    if role_name
      role = Role.find_by(name: role_name)
      if role
        user.roles << role unless user.roles.include?(role)
        puts "✅ Created Super Admin: #{user.email}"
      else
        puts "⚠️  Role '#{role_name}' not found for Super Admin: #{user.email}"
      end
    end
  else
    puts "❌ Failed to create Super Admin: #{user_attrs[:email]} - #{user.errors.full_messages.join(', ')}"
  end
end

# Create tenant-specific users
puts "\n🏢 Creating tenant-specific users..."
tenant_summary = {}

Tenant.active.each do |tenant|
  puts "\n🏢 Setting up users for #{tenant.name} (#{tenant.subdomain})..."

  tenant_users = tenant_users_data[tenant.subdomain] || []
  created_count = 0

  TenantHelper.with_tenant(tenant.subdomain) do
    tenant_users.each do |user_attrs|
      role_name = user_attrs.delete(:role_name)

      user = User.find_or_create_by(email: user_attrs[:email]) do |u|
        u.assign_attributes(user_attrs)
        u.email_verified = true
        u.is_active = true
        u.status = 'active'
        u.language = 'en'
        u.activity = "Created in #{tenant.name} development seeds"
      end

      if user.persisted?
        # Assign role
        if role_name
          role = Role.find_by(name: role_name)
          if role
            user.roles << role unless user.roles.include?(role)
            puts "  ✅ Created user: #{user.email} with role: #{role_name}"
            created_count += 1
          else
            puts "  ⚠️  Role '#{role_name}' not found for user: #{user.email}"
          end
        end
      else
        puts "  ❌ Failed to create user: #{user_attrs[:email]} - #{user.errors.full_messages.join(', ')}"
      end
    end
  end

  tenant_summary[tenant.subdomain] = { name: tenant.name, users: created_count }
end
puts "\n📊 Development Seeding Summary:"
puts " Super Admin users (public schema): #{User.count}"

tenant_summary.each do |subdomain, info|
  TenantHelper.with_tenant(subdomain) do
    total_users = User.count
    puts " #{info[:name]} (#{subdomain}): #{total_users} users"

    # Show role distribution for this tenant
    Role.joins(:users).group('roles.name').count.each do |role_name, count|
      puts "   • #{role_name}: #{count} users"
    end
  end
end

puts "\n🔐 Tenant-specific User Credentials:"

puts "\n🔑 Super Admin (Global Access):"
puts "• superadmin@lbytesecurity.com / SuperSecure123!"
puts "• platform@lbytesecurity.com / PlatformSecure123!"

tenant_users_data.each do |subdomain, users|
  tenant = Tenant.find_by(subdomain: subdomain)
  puts "\n🏢 #{tenant.name} (#{subdomain}.localhost:3000):"

  users.each do |user_data|
    role_name = user_data[:role_name]
    puts "• #{user_data[:email]} / #{user_data[:password]} (#{role_name})"
  end
end

puts "\n🚀 You can now test authentication with these tenant-specific users!"

# Tenant-specific API usage examples
puts "\n📖 Tenant-specific API usage examples:"
puts ""
puts "1. Access Demo tenant:"
puts "   Base URL: http://demo.localhost:3000"
puts "   Login: POST /users/sign_in"
puts "   Body: { \"user\": { \"email\": \"admin@demo.localhost\", \"password\": \"AdminDemo123!\" } }"
puts ""
puts "2. Access Acme tenant:"
puts "   Base URL: http://acme.localhost:3000"
puts "   Login: POST /users/sign_in"
puts "   Body: { \"user\": { \"email\": \"admin@acme.localhost\", \"password\": \"AdminAcme123!\" } }"
puts ""
puts "3. Access Beta tenant:"
puts "   Base URL: http://beta.localhost:3000"
puts "   Login: POST /users/sign_in"
puts "   Body: { \"user\": { \"email\": \"admin@beta.localhost\", \"password\": \"AdminBeta123!\" } }"
puts ""
puts "4. Super Admin (can manage all tenants):"
puts "   Base URL: http://localhost:3000 (any domain)"
puts "   Login: POST /users/sign_in"
puts "   Body: { \"user\": { \"email\": \"superadmin@lbytesecurity.com\", \"password\": \"SuperSecure123!\" } }"
puts "   Manage tenants: GET /api/tenants (requires Super Admin role)"

puts "\n🎯 Testing different tenant isolation:"
puts "• Each tenant has its own users and data"
puts "• Super Admins can access all tenants via /api/tenants"
puts "• Regular users are isolated to their tenant schema"
puts "• Test subdomain routing: demo.localhost, acme.localhost, beta.localhost"

puts "\n� Rails Console tenant testing:"
puts "# Check current tenant"
puts "TenantHelper.current_tenant"
puts ""
puts "# Switch to specific tenant"
puts "TenantHelper.with_tenant('demo') { User.count }"
puts ""
puts "# Manually switch and stay"
puts "TenantHelper.switch_to_schema('acme')"
puts "TenantHelper.current_tenant = Tenant.find_by(subdomain: 'acme')"

puts "\n✨ Tenant-aware user seeding completed successfully!"
