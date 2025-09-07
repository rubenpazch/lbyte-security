FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:user_name) { |n| "user#{n}" }  # Fixed: was 'username', now 'user_name'
    password { "password123" }
    password_confirmation { "password123" }
    status { "active" }
    location { "New York, USA" }
    flag { "us" }
    occupation { "Employee" }
    company_name { "Test Company" }
    activity { "Recently created" }

    # By default, don't assign any roles - let tests be explicit
    # Roles can be added manually in tests that need them

    # Named factories for specific use cases
    trait :admin do
      email { "admin@example.com" }
      user_name { "admin" }  # Fixed: was 'username', now 'user_name'
      occupation { "System Administrator" }
      company_name { "Admin Corp" }
      activity { "Admin user" }

      after(:create) do |user|
        admin_role = Role.find_or_create_by(name: "Admin") do |role|
          role.description = "Regular Administrator with limited access"
          role.level = 50
          role.is_system = true
          role.color = "#007bff"  # Blue color for admin role
          role.icon = "fas fa-user-shield"  # Shield icon for admin role
        end
        user.roles << admin_role unless user.roles.include?(admin_role)
      end
    end

    trait :manager do
      occupation { "Team Manager" }
      company_name { "Management Corp" }
      activity { "Manager user" }

      after(:create) do |user|
        manager_role = create(:role, :manager_role, with_permissions: false)
        user.roles << manager_role
      end
    end

    trait :super_admin do
      email { "superadmin@example.com" }
      user_name { "superadmin" }  # Fixed: was 'username', now 'user_name'
      occupation { "Super Administrator" }
      company_name { "Super Admin Corp" }
      activity { "Super admin user" }

      after(:create) do |user|
        super_admin_role = create(:role, :super_admin_role, with_permissions: false)
        user.roles << super_admin_role
      end
    end

    trait :with_strong_password do
      password { "StrongP@ssw0rd123!" }
      password_confirmation { "StrongP@ssw0rd123!" }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :unverified do
      # Note: email_verified column doesn't exist in current schema
      # This trait can be used for future email verification features
    end

    trait :with_custom_email do
      # This trait can be used with transient attributes
      # factory will allow passing custom email
    end

    # Factory for a user with a specific email
    factory :admin_user, traits: [ :admin ]

    # Factory for a manager user
    factory :manager_user, traits: [ :manager ]

    # Factory for a user with a strong password
    factory :secure_user, traits: [ :with_strong_password ]

    # Factory for testing user
    factory :test_user do
      sequence(:email) { |n| "test#{n}@example.com" }
      sequence(:user_name) { |n| "test#{n}" }  # Fixed: was 'username', now 'user_name'
      occupation { "Test User" }
      company_name { "Test Corp" }
      activity { "Test user" }
    end

    # Factory for demo user
    factory :demo_user do
      sequence(:email) { |n| "demo#{n}@example.com" }
      sequence(:user_name) { |n| "demo#{n}" }  # Fixed: was 'username', now 'user_name'
      occupation { "Demo User" }
      company_name { "Demo Corp" }
      activity { "Demo user" }
    end

    # Factory for inactive user
    factory :inactive_user, traits: [ :inactive ]

    # Factory for unverified user
    factory :unverified_user, traits: [ :unverified ]
  end
end
