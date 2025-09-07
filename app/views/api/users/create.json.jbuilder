json.status do
  json.code 201
  json.message "User created successfully."
end

json.data do
  json.partial! "shared/user", user: @user
end
