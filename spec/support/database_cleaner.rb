# Test setup - relies purely on transactional fixtures
# No database seeding or manual cleanup needed

RSpec.configure do |config|
  # Rails transactional fixtures handle all cleanup automatically
  # Each test runs in its own transaction that gets rolled back
end
