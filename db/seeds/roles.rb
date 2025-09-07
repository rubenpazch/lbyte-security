roles_data = [
  {
    id: "role-001",
    name: "Super Admin",
    description: "Full system access with all permissions",
    color: "#dc2626",
    icon: "Shield",
    is_system: true,
    is_active: true,
    level: 1,
    permission_ids: [
      "perm-001", "perm-002", "perm-003", "perm-004", "perm-005",
      "perm-006", "perm-007", "perm-008", "perm-009", "perm-010",
      "perm-011", "perm-012", "perm-013", "perm-014", "perm-015",
      "perm-016", "perm-017", "perm-018", "perm-019", "perm-020",
      "perm-021", "perm-022", "perm-023", "perm-024", "perm-025",
      "perm-026"
    ]
  },
  {
    id: "role-002",
    name: "Admin",
    description: "Administrative access with most permissions",
    color: "#ea580c",
    icon: "UserCheck",
    is_system: true,
    is_active: true,
    level: 2,
    permission_ids: [
      "perm-001", "perm-002", "perm-003", "perm-005",
      "perm-006", "perm-007", "perm-008", "perm-010",
      "perm-011", "perm-012", "perm-013", "perm-014", "perm-015",
      "perm-016", "perm-017", "perm-018", "perm-019", "perm-020",
      "perm-021", "perm-022", "perm-023", "perm-024", "perm-025",
      "perm-026"
    ]
  },
  {
    id: "role-003",
    name: "Manager",
    description: "Team management with approval permissions",
    color: "#0ea5e9",
    icon: "Users",
    is_system: true,
    is_active: true,
    level: 3,
    permission_ids: [
      "perm-002", "perm-003", "perm-007", "perm-010", "perm-011",
      "perm-012", "perm-014", "perm-015", "perm-016"
    ]
  },
  {
    id: "role-004",
    name: "Accountant",
    description: "Financial data management",
    color: "#10b981",
    icon: "Calculator",
    is_system: true,
    is_active: true,
    level: 4,
    permission_ids: [
      "perm-010", "perm-011", "perm-012", "perm-013",
      "perm-015", "perm-016"
    ]
  },
  {
    id: "role-005",
    name: "User",
    description: "Basic user access for expense management",
    color: "#6b7280",
    icon: "User",
    is_system: true,
    is_active: true,
    level: 5,
    permission_ids: [
      "perm-010", "perm-011", "perm-015"
    ]
  },
  {
    id: "role-006",
    name: "Viewer",
    description: "Read-only access to data",
    color: "#9ca3af",
    icon: "Eye",
    is_system: true,
    is_active: true,
    level: 6,
    permission_ids: [
      "perm-011", "perm-015"
    ]
  },
  {
    id: "role-007",
    name: "Finance Manager",
    description: "Custom role for finance team management",
    color: "#10b981",
    icon: "DollarSign",
    is_system: false,
    is_active: true,
    level: 15,
    permission_ids: [
      "perm-010", "perm-011", "perm-012", "perm-013", "perm-014",
      "perm-018", "perm-019", "perm-020", "perm-021", "perm-022",
      "perm-023", "perm-024", "perm-015", "perm-016", "perm-017"
    ]
  },
  {
    id: "role-008",
    name: "Department Head",
    description: "Custom role for department heads with approval rights",
    color: "#8b5cf6",
    icon: "Crown",
    is_system: false,
    is_active: true,
    level: 25,
    permission_ids: [
      "perm-002", "perm-003", "perm-010", "perm-011", "perm-012",
      "perm-014", "perm-018", "perm-019", "perm-020", "perm-015",
      "perm-016", "perm-023"
    ]
  }
]

puts "Creating roles..."

roles_data.each do |role_data|
  role = Role.find_or_initialize_by(id: role_data[:id])

  if role.new_record?
    role.assign_attributes(role_data.except(:user_count))
    role.user_count = 0

    if role.save
      puts "✓ Created role: #{role.name} (#{role.id})"
    else
      puts "✗ Failed to create role: #{role.name} - #{role.errors.full_messages.join(', ')}"
    end
  else
    puts "• Role already exists: #{role.name} (#{role.id})"
  end
end

puts "\nRoles seeding completed!"
puts "Total roles: #{Role.count}"
puts "System roles: #{Role.system_roles.count}"
puts "Custom roles: #{Role.custom_roles.count}"
