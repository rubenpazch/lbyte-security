json.status do
  json.code 200
  json.message "Signed up successfully but account needs activation."
end

json.data do
  json.partial! "shared/user", user: resource
end
