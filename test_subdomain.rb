#!/usr/bin/env ruby

require_relative 'config/environment'

puts "Testing subdomain extraction:"
puts "testcorp.localhost:3000 -> #{TenantHelper.extract_subdomain('testcorp.localhost:3000')}"
puts "api.testcorp.example.com -> #{TenantHelper.extract_subdomain('api.testcorp.example.com')}"
puts "api.example.com -> #{TenantHelper.extract_subdomain('api.example.com')}"
puts "alpha.localhost:3000 -> #{TenantHelper.extract_subdomain('alpha.localhost:3000')}"
