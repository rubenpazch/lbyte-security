json.status do
  json.code 200
  json.message "User status updated to #{@user.status}."
end

json.data do
  json.partial! "shared/user", user: @user
end
