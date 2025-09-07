json.status do
  json.code 200
  json.message "Role '#{params[:role_name]}' assigned successfully."
end

json.data do
  json.partial! "shared/user", user: @user
end
