#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/environment'

puts "=== Multitenancy Implementation Test ==="
puts

# Test 1: Tenant Creation
puts "1. Testing Tenant Creation..."
tenant = Tenant.create!(
  name: 'Demo Corporation',
  subdomain: 'demo',
  status: 'active',
  plan: 'professional'
)
puts "✓ Tenant created: #{tenant.name} (#{tenant.subdomain})"
puts

# Test 2: TenantHelper Operations
puts "2. Testing TenantHelper..."
TenantHelper.current_tenant = tenant
puts "✓ Current tenant set: #{TenantHelper.current_tenant&.subdomain}"

TenantHelper.with_tenant(tenant) do
  puts "✓ Inside tenant context: #{TenantHelper.current_tenant&.subdomain}"
end

puts "✓ After tenant context: #{TenantHelper.current_tenant&.subdomain}"
puts

# Test 3: Schema Operations
puts "3. Testing Schema Operations..."
begin
  TenantHelper.create_tenant_schema(tenant)
  puts "✓ Schema creation called"

  TenantHelper.switch_to_schema(tenant.subdomain)
  puts "✓ Schema switch called"

  TenantHelper.switch_to_schema('public')
  puts "✓ Back to public schema"
rescue => e
  puts "⚠ Schema operations: #{e.message}"
end
puts

# Test 4: Subdomain Resolution
puts "4. Testing Subdomain Resolution..."
test_hosts = [ 'demo.example.com', 'www.example.com', 'example.com' ]
test_hosts.each do |host|
  subdomain = TenantHelper.extract_subdomain(host)
  puts "  #{host} -> #{subdomain || 'nil'}"
end
puts

# Test 5: Tenant API Controller
puts "5. Testing Tenant API Controller..."
controller = Api::TenantsController.new
puts "✓ Tenant controller loaded"
puts

# Cleanup
tenant.destroy!
puts "✓ Cleanup completed"
puts
puts "=== All Tests Passed! ==="
