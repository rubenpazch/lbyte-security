FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "Role #{n}" }
    description { "Test role description" }
    color { "#6b7280" }
    icon { "User" }
    is_system { false }
    is_active { true }
    sequence(:level) { |n| n + 100 }
    user_count { 0 }

    # Don't create any permissions by default - let tests be explicit

    # System role traits - these create their own permissions as needed
    trait :super_admin_role do
      name { "Super Admin" }
      description { "Full system access with all permissions" }
      color { "#dc2626" }
      icon { "Shield" }
      is_system { true }
      level { 1 }

      # Create permissions after the role is created
      transient do
        with_permissions { true }
      end

      after(:create) do |role, evaluator|
        if evaluator.with_permissions
          # Create a comprehensive set of permissions for super admin
          permissions = [
            create(:permission, name: "Manage Users", resource: "users", action: "manage"),
            create(:permission, name: "Manage System", resource: "system", action: "manage"),
            create(:permission, name: "Create Expenses", resource: "expenses", action: "create"),
            create(:permission, name: "Read Expenses", resource: "expenses", action: "read")
          ]
          role.permissions = permissions
        end
      end
    end

    trait :admin_role do
      name { "Admin" }
      description { "Administrative access with most permissions" }
      color { "#ea580c" }
      icon { "UserCheck" }
      is_system { true }
      level { 2 }

      transient do
        with_permissions { true }
      end

      after(:create) do |role, evaluator|
        if evaluator.with_permissions
          permissions = [
            create(:permission, name: "Admin User Management", resource: "users", action: "manage"),
            create(:permission, name: "Admin Read Expenses", resource: "expenses", action: "read"),
            create(:permission, name: "Admin Create Expenses", resource: "expenses", action: "create")
          ]
          role.permissions = permissions
        end
      end
    end

    trait :manager_role do
      name { "Manager" }
      description { "Team management with approval permissions" }
      color { "#0ea5e9" }
      icon { "Users" }
      is_system { true }
      level { 3 }

      transient do
        with_permissions { true }
      end

      after(:create) do |role, evaluator|
        if evaluator.with_permissions
          permissions = [
            create(:permission, name: "Manager Team Control", resource: "team", action: "manage"),
            create(:permission, name: "Manager Read Expenses", resource: "expenses", action: "read")
          ]
          role.permissions = permissions
        end
      end
    end

    trait :accountant_role do
      name { "Accountant" }
      description { "Financial data management" }
      color { "#10b981" }
      icon { "Calculator" }
      is_system { true }
      level { 4 }

      transient do
        with_permissions { true }
      end

      after(:create) do |role, evaluator|
        if evaluator.with_permissions
          permissions = [
            create(:permission, name: "Accountant Manage Finance", resource: "finance", action: "manage"),
            create(:permission, name: "Accountant Read Expenses", resource: "expenses", action: "read")
          ]
          role.permissions = permissions
        end
      end
    end

    trait :user_role do
      name { "User" }
      description { "Basic user access for expense management" }
      color { "#6b7280" }
      icon { "User" }
      is_system { true }
      level { 5 }

      transient do
        with_permissions { true }
      end

      after(:create) do |role, evaluator|
        if evaluator.with_permissions
          permissions = [
            create(:permission, name: "User Create Expenses", resource: "expenses", action: "create"),
            create(:permission, name: "User Read Expenses", resource: "expenses", action: "read"),
            create(:permission, name: "User View Reports", resource: "reports", action: "read")
          ]
          role.permissions = permissions
        end
      end
    end

    trait :viewer_role do
      name { "Viewer" }
      description { "Read-only access to data" }
      color { "#9ca3af" }
      icon { "Eye" }
      is_system { true }
      level { 6 }

      transient do
        with_permissions { true }
      end

      after(:create) do |role, evaluator|
        if evaluator.with_permissions
          permissions = [
            create(:permission, name: "Viewer Read Data", resource: "data", action: "read")
          ]
          role.permissions = permissions
        end
      end
    end

    # Named factories for system roles
    factory :super_admin_role, traits: [ :super_admin_role ]
    factory :admin_role, traits: [ :admin_role ]
    factory :manager_role, traits: [ :manager_role ]
    factory :accountant_role, traits: [ :accountant_role ]
    factory :user_role, traits: [ :user_role ]
    factory :viewer_role, traits: [ :viewer_role ]

    # Custom role factories
    factory :custom_role do
      is_system { false }
      sequence(:level) { |n| n + 50 }
    end
  end
end
