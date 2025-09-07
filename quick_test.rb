#!/usr/bin/env ruby

# Simple test runner for key fixes
puts "🧪 Testing Key Fixes"
puts "=" * 50

# Test 1: Subdomain extraction
puts "\n1. Testing Subdomain Extraction"
require_relative 'config/environment'

test_cases = {
  'testcorp.localhost:3000' => 'testcorp',
  'api.testcorp.example.com' => 'api',
  'api.example.com' => nil,
  'alpha.localhost:3000' => 'alpha'
}

test_cases.each do |host, expected|
  actual = TenantHelper.extract_subdomain(host)
  status = actual == expected ? "✅" : "❌"
  puts "  #{host} -> #{actual.inspect} (expected: #{expected.inspect}) #{status}"
end

# Test 2: Check if files exist and have correct structure
puts "\n2. Checking File Structure"
files_to_check = [
  'app/views/api/users/index.json.jbuilder',
  'app/views/sessions/create.json.jbuilder',
  'app/views/shared/_user.json.jbuilder'
]

files_to_check.each do |file|
  if File.exist?(file)
    content = File.read(file)
    if file.include?('users/index')
      has_data = content.include?('json.data')
      puts "  #{file}: #{has_data ? '✅ has json.data' : '❌ missing json.data'}"
    elsif file.include?('sessions/create')
      has_message = content.include?('json.message')
      has_user = content.include?('json.user')
      puts "  #{file}: #{has_message && has_user ? '✅ has message & user' : '❌ missing structure'}"
    else
      puts "  #{file}: ✅ exists"
    end
  else
    puts "  #{file}: ❌ missing"
  end
end

puts "\n✅ Basic checks complete"
