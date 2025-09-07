json.status do
  json.code 200
  json.message "User retrieved successfully."
end

json.data do
  json.partial! "shared/user", user: @user
end
