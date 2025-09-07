# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting seeds for #{Rails.env} environment..."

# Load tenants first (creates schemas for multitenancy)
load Rails.root.join('db', 'seeds', 'tenants.rb')

# Load permissions first (required for all environments)
load Rails.root.join('db', 'seeds', 'permissions.rb')

# Load roles second (depends on permissions)
load Rails.root.join('db', 'seeds', 'roles.rb')

# Load environment-specific seeds
case Rails.env
when 'development'
  load Rails.root.join('db', 'seeds', 'development.rb')
when 'production'
  load Rails.root.join('db', 'seeds', 'production.rb')
when 'test'
  load Rails.root.join('db', 'seeds', 'test.rb')
else
  puts "⚠️  Unknown environment: #{Rails.env}"
  puts "   Loading development seeds as fallback..."
  load Rails.root.join('db', 'seeds', 'development.rb')
end

puts "✅ Seeding completed for #{Rails.env} environment"
