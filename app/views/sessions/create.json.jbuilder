json.message "Logged in successfully."
json.user do
  json.partial! "shared/user", user: resource
end

# Include tenant information if available
if current_tenant
  json.tenant do
    json.id current_tenant.id
    json.name current_tenant.name
    json.subdomain current_tenant.subdomain
    json.plan current_tenant.plan
    json.status current_tenant.status
  end
else
  json.tenant nil
end
