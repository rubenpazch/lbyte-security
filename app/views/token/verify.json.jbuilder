json.valid true
json.user do
  json.partial! "shared/user", user: current_user
end
json.message "Token is valid"
