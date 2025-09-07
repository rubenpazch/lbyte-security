json.status do
  json.code 200
  json.message "Users retrieved successfully."
end

json.data @users do |user|
  json.partial! "shared/user", user: user
end

json.pagination do
  json.current_page @current_page
  json.per_page @per_page
  json.total_count @total_count
  json.total_pages @total_pages
end
