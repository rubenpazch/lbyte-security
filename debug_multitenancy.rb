#!/usr/bin/env ruby

require_relative 'config/environment'

puts "=== Testing Subdomain Extraction ==="
test_cases = [
  'testcorp.localhost:3000',
  'api.testcorp.example.com',
  'api.example.com',
  'alpha.localhost:3000'
]

test_cases.each do |host|
  result = TenantHelper.extract_subdomain(host)
  puts "#{host} -> #{result.inspect}"
end

puts "\n=== Testing Tenant Resolution ==="
# Create test tenants for resolution
alpha_tenant = Tenant.find_or_create_by(subdomain: 'alpha') do |t|
  t.name = 'Alpha Corp'
  t.status = 'active'
  t.plan = 'enterprise'
end

result = TenantHelper.find_tenant_by_subdomain('alpha')
puts "find_tenant_by_subdomain('alpha') -> #{result&.name || 'nil'}"

puts "\n=== Testing Role Creation ==="
super_admin_role = Role.find_or_create_by(name: "Super Admin") do |role|
  role.description = "System Super Administrator"
  role.level = 100
  role.is_system = true
end

puts "Super Admin role exists: #{super_admin_role.persisted?}"
puts "Super Admin role name: #{super_admin_role.name}"
