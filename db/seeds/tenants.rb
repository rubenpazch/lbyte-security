# frozen_string_literal: true

# Create default tenant for development
default_tenant = Tenant.find_or_create_by(subdomain: 'demo') do |tenant|
  tenant.name = 'Demo Organization'
  tenant.status = 'active'
  tenant.plan = 'enterprise'
  tenant.description = 'Default demo tenant for development'
  tenant.contact_email = 'admin@demo.localhost'
  tenant.contact_name = 'Demo Admin'
end

puts "✅ Created/found tenant: #{default_tenant.name} (#{default_tenant.subdomain})"

# Create additional sample tenants for testing
sample_tenants = [
  {
    name: 'Acme Corporation',
    subdomain: 'acme',
    plan: 'enterprise',
    contact_email: 'admin@acme.com'
  },
  {
    name: 'Beta Industries',
    subdomain: 'beta',
    plan: 'professional',
    contact_email: 'admin@beta.com'
  },
  {
    name: 'Gamma Solutions',
    subdomain: 'gamma',
    plan: 'basic',
    status: 'trial',
    trial_ends_at: 30.days.from_now,
    contact_email: 'trial@gamma.com'
  }
]

sample_tenants.each do |tenant_data|
  tenant = Tenant.find_or_create_by(subdomain: tenant_data[:subdomain]) do |t|
    tenant_data.each { |key, value| t.send("#{key}=", value) }
  end

  puts "✅ Created/found tenant: #{tenant.name} (#{tenant.subdomain})"

  # Create schema and seed with basic data for each tenant
  begin
    # Create schema if it doesn't exist
    TenantHelper.create_tenant_schema(tenant.subdomain)

    # Switch to tenant and seed with default roles/permissions
    TenantHelper.with_tenant(tenant.subdomain) do
      # Load default roles and permissions for this tenant
      load Rails.root.join('db', 'seeds', 'roles.rb')
      load Rails.root.join('db', 'seeds', 'permissions.rb')

      # Create a default admin user for each tenant
      admin_user = User.find_or_create_by(email: "admin@#{tenant.subdomain}.localhost") do |user|
        user.username = "admin"
        user.first_name = "Admin"
        user.last_name = "User"
        user.password = "password123"
        user.password_confirmation = "password123"
        user.is_admin = true
        user.email_verified = true
      end

      # Assign Super Admin role
      admin_user.add_role("Super Admin") if admin_user.persisted?

      puts "  ✅ Created admin user for #{tenant.name}: #{admin_user.email}"
    end
  rescue => e
    puts "  ⚠️  Error setting up tenant #{tenant.subdomain}: #{e.message}"
  end
end

puts "\n🎉 Tenant seeding completed!"
puts "You can now access tenants at:"
Tenant.active.each do |tenant|
  puts "  - #{tenant.name}: http://#{tenant.subdomain}.localhost:3000"
end
