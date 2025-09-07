permissions_data = [
  # User Management Permissions
  {
    id: "perm-001",
    name: "Create Users",
    description: "Ability to create new user accounts",
    resource: "users",
    action: "create",
    is_system: true
  },
  {
    id: "perm-002",
    name: "Read Users",
    description: "Ability to view user information",
    resource: "users",
    action: "read",
    is_system: true
  },
  {
    id: "perm-003",
    name: "Update Users",
    description: "Ability to modify user accounts",
    resource: "users",
    action: "update",
    is_system: true
  },
  {
    id: "perm-004",
    name: "Delete Users",
    description: "Ability to delete user accounts",
    resource: "users",
    action: "delete",
    is_system: true
  },

  # Role Management Permissions
  {
    id: "perm-005",
    name: "Manage Roles",
    description: "Ability to create, edit, and delete roles",
    resource: "roles",
    action: "manage",
    is_system: true
  },
  {
    id: "perm-006",
    name: "Assign Roles",
    description: "Ability to assign roles to users",
    resource: "roles",
    action: "assign",
    is_system: true
  },

  # Permission Management
  {
    id: "perm-007",
    name: "Manage Permissions",
    description: "Ability to create, edit, and delete permissions",
    resource: "permissions",
    action: "manage",
    is_system: true
  },

  # System Administration
  {
    id: "perm-008",
    name: "System Settings",
    description: "Access to system configuration settings",
    resource: "system",
    action: "configure",
    is_system: true
  },
  {
    id: "perm-009",
    name: "System Logs",
    description: "Access to view system logs and audit trails",
    resource: "system",
    action: "logs",
    is_system: true
  },

  # Financial/Expense Management
  {
    id: "perm-010",
    name: "Create Expenses",
    description: "Ability to create expense records",
    resource: "expenses",
    action: "create",
    is_system: true
  },
  {
    id: "perm-011",
    name: "View Expenses",
    description: "Ability to view expense records",
    resource: "expenses",
    action: "read",
    is_system: true
  },
  {
    id: "perm-012",
    name: "Edit Expenses",
    description: "Ability to modify expense records",
    resource: "expenses",
    action: "update",
    is_system: true
  },
  {
    id: "perm-013",
    name: "Delete Expenses",
    description: "Ability to delete expense records",
    resource: "expenses",
    action: "delete",
    is_system: true
  },
  {
    id: "perm-014",
    name: "Approve Expenses",
    description: "Ability to approve or reject expense claims",
    resource: "expenses",
    action: "approve",
    is_system: true
  },

  # Reports and Analytics
  {
    id: "perm-015",
    name: "View Reports",
    description: "Access to view financial and expense reports",
    resource: "reports",
    action: "read",
    is_system: true
  },
  {
    id: "perm-016",
    name: "Generate Reports",
    description: "Ability to generate custom reports",
    resource: "reports",
    action: "generate",
    is_system: true
  },
  {
    id: "perm-017",
    name: "Export Data",
    description: "Ability to export data in various formats",
    resource: "reports",
    action: "export",
    is_system: true
  },

  # Budget Management
  {
    id: "perm-018",
    name: "Create Budgets",
    description: "Ability to create budget plans",
    resource: "budgets",
    action: "create",
    is_system: true
  },
  {
    id: "perm-019",
    name: "View Budgets",
    description: "Ability to view budget information",
    resource: "budgets",
    action: "read",
    is_system: true
  },
  {
    id: "perm-020",
    name: "Update Budgets",
    description: "Ability to modify budget plans",
    resource: "budgets",
    action: "update",
    is_system: true
  },
  {
    id: "perm-021",
    name: "Delete Budgets",
    description: "Ability to delete budget plans",
    resource: "budgets",
    action: "delete",
    is_system: true
  },

  # Category Management
  {
    id: "perm-022",
    name: "Manage Categories",
    description: "Ability to create, edit, and delete expense categories",
    resource: "categories",
    action: "manage",
    is_system: true
  },

  # Team Management
  {
    id: "perm-023",
    name: "Manage Teams",
    description: "Ability to create and manage teams",
    resource: "teams",
    action: "manage",
    is_system: true
  },
  {
    id: "perm-024",
    name: "View Team Data",
    description: "Access to view team expense data",
    resource: "teams",
    action: "read",
    is_system: true
  },

  # Integration Management
  {
    id: "perm-025",
    name: "API Access",
    description: "Access to API endpoints and external integrations",
    resource: "api",
    action: "access",
    is_system: true
  },
  {
    id: "perm-026",
    name: "Webhooks",
    description: "Ability to manage webhook configurations",
    resource: "webhooks",
    action: "manage",
    is_system: true
  }
]

puts "Creating permissions..."

permissions_data.each do |permission_data|
  permission = Permission.find_or_initialize_by(id: permission_data[:id])

  if permission.new_record?
    permission.assign_attributes(permission_data)

    if permission.save
      puts "✓ Created permission: #{permission.name} (#{permission.id})"
    else
      puts "✗ Failed to create permission: #{permission.name} - #{permission.errors.full_messages.join(', ')}"
    end
  else
    # Update existing permission
    permission.assign_attributes(permission_data.except(:id))
    if permission.save
      puts "• Updated permission: #{permission.name} (#{permission.id})"
    else
      puts "✗ Failed to update permission: #{permission.name} - #{permission.errors.full_messages.join(', ')}"
    end
  end
end

puts "\nPermissions seeding completed!"
puts "Total permissions: #{Permission.count}"
puts "System permissions: #{Permission.system_permissions.count}"
puts "Custom permissions: #{Permission.custom_permissions.count}"

# Now sync permissions with existing roles
puts "\nSyncing permissions with roles..."

role_permissions_mapping = {
  "role-001" => permissions_data.map { |p| p[:id] }, # Super Admin gets all
  "role-002" => permissions_data.reject { |p| p[:id] == "perm-004" }.map { |p| p[:id] }, # Admin gets all except delete users
  "role-003" => [ "perm-002", "perm-003", "perm-007", "perm-010", "perm-011", "perm-012", "perm-014", "perm-015", "perm-016" ], # Manager
  "role-004" => [ "perm-010", "perm-011", "perm-012", "perm-013", "perm-015", "perm-016" ], # Accountant
  "role-005" => [ "perm-010", "perm-011", "perm-015" ], # User
  "role-006" => [ "perm-011", "perm-015" ], # Viewer
  "role-007" => [ "perm-010", "perm-011", "perm-012", "perm-013", "perm-014", "perm-018", "perm-019", "perm-020", "perm-021", "perm-022", "perm-023", "perm-024", "perm-015", "perm-016", "perm-017" ], # Finance Manager
  "role-008" => [ "perm-002", "perm-003", "perm-010", "perm-011", "perm-012", "perm-014", "perm-018", "perm-019", "perm-020", "perm-015", "perm-016", "perm-023" ] # Department Head
}

Role.find_each do |role|
  if role_permissions_mapping[role.id]
    # Clear existing permission associations
    role.permissions.clear

    # Add permissions based on mapping
    permission_ids = role_permissions_mapping[role.id]
    permissions_to_add = Permission.where(id: permission_ids)

    role.permissions = permissions_to_add
    role.permission_ids = permission_ids # Update JSON field for backward compatibility

    if role.save
      puts "✓ Synced #{permissions_to_add.count} permissions for role: #{role.name}"
    else
      puts "✗ Failed to sync permissions for role: #{role.name}"
    end
  end
end

puts "\nPermissions and roles sync completed!"
