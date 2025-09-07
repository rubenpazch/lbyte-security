json.id user.id
json.email user.email
json.username user.user_name  # Fixed: use user_name database column
json.user_name user.user_name  # Include both for API compatibility
json.full_name user.fullname   # Use the fullname method from model

json.phone user.phone
json.occupation user.occupation
json.company_name user.company_name
json.location user.location
json.flag user.flag
json.status user.status
json.activity user.activity
json.pic user.pic
json.avatar user.avatar
# Note: email_verified column doesn't exist in current schema
json.email_verified (user.status == 'active')  # Use status as proxy for verification
json.created_at user.created_at
json.updated_at user.updated_at

# Include roles if user has any
if user.roles.any?
  json.roles user.roles.pluck(:name)
  json.role_details user.roles do |role|
    json.id role.id
    json.name role.name
    json.description role.description
    json.color role.color
    json.icon role.icon
    json.level role.level
    json.is_system role.is_system
    json.is_active role.is_active  # Role model does have is_active column
  end
else
  json.roles []
  json.role_details []
end

# Include permissions if user has any
permissions = user.roles.joins(:permissions).pluck("permissions.name").uniq
if permissions.any?
  json.permissions permissions
else
  json.permissions []
end
