json.status do
  json.code 200
  json.message "Signed up successfully."
end

json.data do
  json.user do
    json.partial! "shared/user", user: resource
  end
end
