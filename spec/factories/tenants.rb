# frozen_string_literal: true

FactoryBot.define do
  factory :tenant do
    sequence(:name) { |n| "Organization #{n}" }
    sequence(:subdomain) { |n| "org#{n}" }
    status { 'active' }
    plan { 'basic' }
    settings { {} }
    description { "Test organization for development" }
    contact_email { "admin@example.com" }
    contact_name { "Test Admin" }

    trait :active do
      status { 'active' }
    end

    trait :inactive do
      status { 'inactive' }
    end

    trait :trial do
      status { 'trial' }
      plan { 'basic' }  # Trial tenants can have a basic plan
      trial_ends_at { 30.days.from_now }
    end

    trait :suspended do
      status { 'suspended' }
    end

    trait :enterprise do
      plan { 'enterprise' }
    end

    trait :professional do
      plan { 'professional' }
    end

    trait :basic do
      plan { 'basic' }
    end

    trait :with_custom_settings do
      settings do
        {
          features: [ 'advanced_analytics', 'custom_branding' ],
          limits: { users: 100, storage: '10GB' },
          theme: { primary_color: '#007bff', logo_url: 'https://example.com/logo.png' }
        }
      end
    end

    trait :expiring_soon do
      trial_ends_at { 3.days.from_now }
    end

    trait :expired do
      trial_ends_at { 1.day.ago }
      status { 'inactive' }
    end
  end
end
