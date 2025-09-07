FactoryBot.define do
  factory :permission do
    sequence(:name) { |n| "Test Permission #{n}" }
    description { "Test permission description" }
    sequence(:resource) { |n| "test_resource_#{n}" }
    sequence(:action) { |n| "test_action_#{n}" }
    is_system { true }

    # Let the model auto-generate IDs - don't force specific ones

    # System permission traits
    trait :create_users do
      id { "perm-001" }
      name { "Create Users" }
      description { "Ability to create new user accounts" }
      resource { "users" }
      action { "create" }
    end

    trait :read_users do
      id { "perm-002" }
      name { "Read Users" }
      description { "Ability to view user information" }
      resource { "users" }
      action { "read" }
    end

    trait :update_users do
      id { "perm-003" }
      name { "Update Users" }
      description { "Ability to modify user accounts" }
      resource { "users" }
      action { "update" }
    end

    trait :delete_users do
      id { "perm-004" }
      name { "Delete Users" }
      description { "Ability to delete user accounts" }
      resource { "users" }
      action { "delete" }
    end

    trait :manage_roles do
      id { "perm-005" }
      name { "Manage Roles" }
      description { "Ability to create, edit, and delete roles" }
      resource { "roles" }
      action { "manage" }
    end

    trait :create_expenses do
      id { "perm-010" }
      name { "Create Expenses" }
      description { "Ability to create expense records" }
      resource { "expenses" }
      action { "create" }
    end

    trait :view_expenses do
      id { "perm-011" }
      name { "View Expenses" }
      description { "Ability to view expense records" }
      resource { "expenses" }
      action { "read" }
    end

    trait :view_reports do
      id { "perm-015" }
      name { "View Reports" }
      description { "Access to view financial and expense reports" }
      resource { "reports" }
      action { "read" }
    end

    trait :custom_permission do
      is_system { false }
      sequence(:resource) { |n| "custom_resource_#{n}" }
    end

    # Named factories for commonly used permissions
    factory :create_users_permission, traits: [ :create_users ]
    factory :read_users_permission, traits: [ :read_users ]
    factory :update_users_permission, traits: [ :update_users ]
    factory :delete_users_permission, traits: [ :delete_users ]
    factory :manage_roles_permission, traits: [ :manage_roles ]
    factory :create_expenses_permission, traits: [ :create_expenses ]
    factory :view_expenses_permission, traits: [ :view_expenses ]
    factory :view_reports_permission, traits: [ :view_reports ]
    factory :custom_permission, traits: [ :custom_permission ]
  end
end
