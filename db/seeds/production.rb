# Production environment specific seeds
# This file should only contain essential data needed for production

puts "🌱 Seeding production data..."

# In production, you typically don't want to create sample users
# Instead, you might want to create essential system data, configurations, etc.

# Example: Create an admin user if it doesn't exist (commented out for security)
# if User.where(email: 'admin@yourdomain.com').empty?
#   User.create!(
#     email: 'admin@yourdomain.com',
#     password: ENV['ADMIN_PASSWORD'] || SecureRandom.hex(16),
#     password_confirmation: ENV['ADMIN_PASSWORD'] || SecureRandom.hex(16)
#   )
#   puts "✅ Created admin user"
# end

puts "✅ Production seeding completed"
puts "⚠️  Remember to create admin users manually in production for security"
