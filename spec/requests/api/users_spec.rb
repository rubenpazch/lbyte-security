require 'rails_helper'

RSpec.describe "Api::Users", type: :request do
  # Create roles first
  let!(:user_role) { create(:role, name: "User") }
  let!(:admin_role) { create(:role, name: "Admin") }
  let!(:manager_role) { create(:role, name: "Manager") }
  let!(:super_admin_role) { create(:role, name: "Super Admin") }

  let!(:regular_user) { create(:user, email: "regular@test.com", user_name: "regular") }  # Fixed: username → user_name
  let!(:admin_user) do
    user = create(:user, email: "admin@test.com", user_name: "admintest", occupation: "Administrator")  # Fixed: removed non-existent fields
    user.roles << admin_role
    user
  end
  let!(:manager_user) do
    user = create(:user, email: "manager@test.com", user_name: "manager", occupation: "Manager")  # Fixed: removed non-existent fields
    user.roles << manager_role
    user
  end

  let(:regular_token) { sign_in_user(regular_user) }
  let(:admin_token) { sign_in_user(admin_user) }
  let(:manager_token) { sign_in_user(manager_user) }

  describe "GET /api/users" do
    before do
      # Create test users with different roles and statuses
      create_list(:user, 3)
      create(:user, email: "inactive@test.com", user_name: "inactive", status: 'inactive')  # Fixed: username → user_name
      create(:user, email: "searchme@test.com", user_name: "searchme", occupation: 'SearchMe')  # Fixed: username → user_name, first_name → occupation
    end

    context "without authentication" do
      it "returns users list (public endpoint)" do
        get "/api/users"

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["code"]).to eq(200)
        expect(response_body["data"]).to be_an(Array)
        expect(response_body["pagination"]).to be_present
      end
    end

    context "with authentication" do
      it "returns paginated users list" do
        get "/api/users", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]).to be_an(Array)
      end

      it "filters users by status" do
        get "/api/users?status=active", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        active_users = response_body["data"]
        expect(active_users.all? { |user| user["status"] == "active" }).to be true
      end

      it "filters users by role" do
        get "/api/users?role=Admin", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        admin_users = response_body["data"]
        expect(admin_users.any? { |user| user["roles"].include?("Admin") }).to be true
      end

      it "searches users by name, email, or user_name" do  # Fixed: updated description
        get "/api/users?search=SearchMe", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        search_results = response_body["data"]
        expect(search_results.any? { |user| user["occupation"] == "SearchMe" }).to be true  # Fixed: first_name → occupation
      end

      it "supports pagination parameters" do
        get "/api/users?page=1&per_page=2", headers: { 'Authorization' => admin_token }

        response_body = JSON.parse(response.body)
        expect(response_body["data"].size).to be <= 2
        expect(response_body["pagination"]["per_page"]).to eq(2)
      end
    end
  end

  describe "GET /api/users/:id" do
    let(:user) { create(:user, user_name: "jane_doe", occupation: "Tester") }  # Fixed: username → user_name, first_name → occupation
    
    it "returns user by id" do
      get "/api/users/#{user.id}", headers: { 'Authorization' => @auth_token }
      
      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["data"]["user_name"]).to eq("jane_doe")  # Fixed: username → user_name
      expect(response_body["data"]["occupation"]).to eq("Tester")  # Fixed: first_name → occupation
    end
  end

  describe "POST /api/users" do
    let(:valid_user_params) do
      {
        user: {
          email: "newuser@example.com",
          user_name: "newuser",  # Fixed: username → user_name
          password: "password123",
          password_confirmation: "password123",
          occupation: "New User",  # Fixed: use occupation instead of first_name/last_name
          company_name: "Test Corp",
          role_names: [ "User" ]
        }
      }
    end

    let(:invalid_user_params) do
      {
        user: {
          email: "",
          user_name: "",  # Fixed: username → user_name
          password: "123",
          password_confirmation: "456"
        }
      }
    end

    context "without authentication" do
      it "returns unauthorized error" do
        post "/api/users", params: valid_user_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user authentication" do
      it "returns forbidden error" do
        post "/api/users", params: valid_user_params, headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin authentication" do
      it "creates a new user with valid params" do
        post "/api/users", params: valid_user_params, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:created)

        response_body = JSON.parse(response.body)
        expect(response_body["status"]["code"]).to eq(201)
        expect(response_body["data"]["email"]).to eq("newuser@example.com")
        expect(response_body["data"]["roles"]).to include("User")

        # Verify user was actually created
        created_user = User.find_by(email: "newuser@example.com")
        expect(created_user).to be_present
        expect(created_user.roles.pluck(:name)).to include("User")
      end

      it "creates user with multiple roles" do
        params_with_roles = valid_user_params.deep_dup
        params_with_roles[:user][:role_names] = [ "User", "Manager" ]
        params_with_roles[:user][:email] = "multiuser@example.com"
        params_with_roles[:user][:user_name] = "multiuser"  # Fixed: username → user_name

        post "/api/users", params: params_with_roles, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:created)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]["roles"]).to include("User", "Manager")
      end

      it "returns validation errors with invalid params" do
        post "/api/users", params: invalid_user_params, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to be_present
        expect(response_body["errors"]).to be_an(Array)
      end

      it "handles duplicate email error" do
        existing_user = create(:user, email: "existing@test.com", user_name: "existing")  # Fixed: username → user_name
        duplicate_params = valid_user_params.deep_dup
        duplicate_params[:user][:email] = existing_user.email
        duplicate_params[:user][:user_name] = "different"  # Fixed: username → user_name

        post "/api/users", params: duplicate_params, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["errors"]).to include(a_string_matching(/email.*already.*taken/i))
      end
    end
  end

  describe "PUT /api/users/:id" do
    let(:target_user) { create(:user, email: "target3@test.com", user_name: "target3") }  # Fixed: username → user_name
    let(:update_params) do
      {
        user: {
          occupation: "Updated Occupation",  # Fixed: use occupation instead of first_name/last_name
          company_name: "Updated Company",
          role_names: [ "Manager" ]
        }
      }
    end

    context "without authentication" do
      it "returns unauthorized error" do
        put "/api/users/#{target_user.id}", params: update_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user authentication" do
      it "allows user to update their own profile" do
        put "/api/users/#{regular_user.id}",
            params: { user: { occupation: "Self Updated" } },  # Fixed: first_name → occupation
            headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]["occupation"]).to eq("Self Updated")  # Fixed: first_name → occupation
      end

      it "prevents user from updating other users" do
        put "/api/users/#{target_user.id}",
            params: update_params,
            headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end

      it "prevents regular user from changing roles" do
        put "/api/users/#{regular_user.id}",
            params: { user: { role_names: [ "Admin" ] } },
            headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:ok)
        # Role should not change for regular users
        updated_user = User.find(regular_user.id)
        expect(updated_user.roles.pluck(:name)).not_to include("Admin")
      end
    end

    context "with admin authentication" do
      it "updates user with valid params" do
        put "/api/users/#{target_user.id}", params: update_params, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]["occupation"]).to eq("Updated Occupation")  # Fixed: first_name → occupation
        expect(response_body["data"]["company_name"]).to eq("Updated Company")  # Fixed: test actual field instead of language
        expect(response_body["data"]["roles"]).to include("Manager")
      end

      it "allows admin to update any user" do
        other_user = create(:user, email: "other@test.com", user_name: "other")  # Fixed: username → user_name
        put "/api/users/#{other_user.id}",
            params: { user: { occupation: "Admin Updated" } },  # Fixed: first_name → occupation
            headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]["occupation"]).to eq("Admin Updated")  # Fixed: first_name → occupation
      end

      it "returns validation errors with invalid params" do
        put "/api/users/#{target_user.id}",
            params: { user: { email: "" } },
            headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["errors"]).to be_present
      end
    end

    context "when user does not exist" do
      it "returns 404 error" do
        put "/api/users/99999", params: update_params, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/users/:id" do
    let(:target_user) { create(:user, email: "target4@test.com", user_name: "target4") }  # Fixed: username → user_name

    context "without authentication" do
      it "returns unauthorized error" do
        delete "/api/users/#{target_user.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user authentication" do
      it "cannot delete their own account" do
        delete "/api/users/#{regular_user.id}", headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("You cannot delete your own account through this endpoint.")
      end

      it "prevents user from deleting other users" do
        delete "/api/users/#{target_user.id}", headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin authentication" do
      it "allows admin to delete any user" do
        user_id = target_user.id

        delete "/api/users/#{user_id}", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("User deleted successfully.")

        # Verify user was actually deleted
        expect(User.find_by(id: user_id)).to be_nil
      end

      it "prevents admin from deleting themselves" do
        delete "/api/users/#{admin_user.id}", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:forbidden)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("You cannot delete your own account through this endpoint.")
      end
    end

    context "when user does not exist" do
      it "returns 404 error" do
        delete "/api/users/99999", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/users/:id/assign_role" do
    let(:target_user) { create(:user, email: "target@test.com", user_name: "target") }  # Fixed: username → user_name

    context "without authentication" do
      it "returns unauthorized error" do
        post "/api/users/#{target_user.id}/assign_role", params: { role_name: "Manager" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user authentication" do
      it "returns forbidden error" do
        post "/api/users/#{target_user.id}/assign_role",
             params: { role_name: "Manager" },
             headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin authentication" do
      it "assigns role to user successfully" do
        post "/api/users/#{target_user.id}/assign_role",
             params: { role_name: "Manager" },
             headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role 'Manager' assigned successfully.")
        expect(response_body["data"]["roles"]).to include("Manager")

        target_user.reload
        expect(target_user.roles.pluck(:name)).to include("Manager")
      end

      it "returns error when role does not exist" do
        post "/api/users/#{target_user.id}/assign_role",
             params: { role_name: "NonexistentRole" },
             headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:not_found)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role 'NonexistentRole' not found.")
      end

      it "handles already assigned role" do
        target_user.roles << manager_role

        post "/api/users/#{target_user.id}/assign_role",
             params: { role_name: "Manager" },
             headers: { 'Authorization' => admin_token }

        # Should return an error when role is already assigned
        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role couldn't be assigned.")
      end

      it "requires role_name parameter" do
        post "/api/users/#{target_user.id}/assign_role",
             params: {},
             headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:bad_request)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role name is required.")
      end
    end

    context "when user does not exist" do
      it "returns 404 error" do
        post "/api/users/99999/assign_role",
             params: { role_name: "Manager" },
             headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/users/:id/remove_role" do
    let(:target_user) do
      user = create(:user, email: "target2@test.com", user_name: "target2")  # Fixed: username → user_name
      user.roles << manager_role
      user
    end

    context "without authentication" do
      it "returns unauthorized error" do
        delete "/api/users/#{target_user.id}/remove_role", params: { role_name: "Manager" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user authentication" do
      it "returns forbidden error" do
        delete "/api/users/#{target_user.id}/remove_role",
               params: { role_name: "Manager" },
               headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin authentication" do
      it "removes role from user successfully" do
        expect(target_user.roles.pluck(:name)).to include("Manager")

        delete "/api/users/#{target_user.id}/remove_role",
               params: { role_name: "Manager" },
               headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role 'Manager' removed successfully.")
        expect(response_body["data"]["roles"]).not_to include("Manager")

        target_user.reload
        expect(target_user.roles.pluck(:name)).not_to include("Manager")
      end

      it "returns error when role does not exist" do
        delete "/api/users/#{target_user.id}/remove_role",
               params: { role_name: "NonexistentRole" },
               headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role couldn't be removed or user doesn't have this role.")
      end

      it "handles role not assigned to user gracefully" do
        delete "/api/users/#{target_user.id}/remove_role",
               params: { role_name: "Admin" },
               headers: { 'Authorization' => admin_token }

        # Controller always returns success even if role wasn't assigned
        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role 'Admin' removed successfully.")
      end

      it "requires role_name parameter" do
        delete "/api/users/#{target_user.id}/remove_role",
               params: {},
               headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:bad_request)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Role name is required.")
      end
    end

    context "when user does not exist" do
      it "returns 404 error" do
        delete "/api/users/99999/remove_role",
               params: { role_name: "Manager" },
               headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/users/:id/toggle_status" do
    let(:active_user) { create(:user, email: "active@test.com", user_name: "active", status: 'active') }  # Fixed: username → user_name
    let(:inactive_user) { create(:user, email: "inactive@test.com", user_name: "inactive", status: 'inactive') }  # Fixed: username → user_name

    context "without authentication" do
      it "returns unauthorized error" do
        post "/api/users/#{active_user.id}/toggle_status"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user authentication" do
      it "returns forbidden error for other users" do
        post "/api/users/#{active_user.id}/toggle_status", headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end

      it "cannot toggle their own status (admin-only action)" do
        post "/api/users/#{regular_user.id}/toggle_status", headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Access denied. Admin privileges required.")
      end
    end

    context "with admin authentication" do
      it "toggles active user to inactive" do
        expect(active_user.status).to eq('active')

        post "/api/users/#{active_user.id}/toggle_status", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("User status updated to inactive.")
        expect(response_body["data"]["status"]).to eq("inactive")

        active_user.reload
        expect(active_user.status).to eq('inactive')
      end

      it "toggles inactive user to active" do
        expect(inactive_user.status).to eq('inactive')

        post "/api/users/#{inactive_user.id}/toggle_status", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]["status"]).to eq("active")

        inactive_user.reload
        expect(inactive_user.status).to eq('active')
      end
    end

    context "when user does not exist" do
      it "returns 404 error" do
        post "/api/users/99999/toggle_status", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "Authorization edge cases" do
    context "with manager user" do
      it "cannot perform admin-only actions" do
        target_user = create(:user, email: "target5@test.com", user_name: "target5")  # Fixed: username → user_name

        # Test create action
        post "/api/users",
             params: { user: { email: "test@example.com", password: "password123" } },
             headers: { 'Authorization' => manager_token }
        expect(response).to have_http_status(:forbidden)

        # Test role assignment
        post "/api/users/#{target_user.id}/assign_role",
             params: { role_name: "User" },
             headers: { 'Authorization' => manager_token }
        expect(response).to have_http_status(:forbidden)

        # Test status toggle for other users
        post "/api/users/#{target_user.id}/toggle_status",
             headers: { 'Authorization' => manager_token }
        expect(response).to have_http_status(:forbidden)
      end

      it "can update their own profile" do
        put "/api/users/#{manager_user.id}",
            params: { user: { occupation: "Updated Manager" } },  # Fixed: first_name → occupation
            headers: { 'Authorization' => manager_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]["occupation"]).to eq("Updated Manager")  # Fixed: first_name → occupation
      end
    end
  end

  describe "Response format validation" do
    let(:target_user) { manager_user }

    it "returns consistent response format for successful operations" do
      get "/api/users/#{target_user.id}", headers: { 'Authorization' => admin_token }

      response_body = JSON.parse(response.body)
      expect(response_body).to have_key("status")
      expect(response_body).to have_key("data")
      expect(response_body["status"]).to have_key("code")
      expect(response_body["status"]).to have_key("message")
      expect(response_body["data"]).to have_key("id")
      expect(response_body["data"]).to have_key("email")
      expect(response_body["data"]).to have_key("roles")
    end

    it "returns consistent error format for failed operations" do
      get "/api/users/99999", headers: { 'Authorization' => admin_token }

      response_body = JSON.parse(response.body)
      expect(response_body).to have_key("status")
      expect(response_body["status"]).to have_key("message")
      expect(response_body["status"]["message"]).to eq("User not found.")
    end
  end

  describe "Performance and pagination" do
    before do
      create_list(:user, 25) # Create enough users to test pagination
    end

    it "respects per_page limits" do
      get "/api/users?per_page=5", headers: { 'Authorization' => admin_token }

      response_body = JSON.parse(response.body)
      expect(response_body["data"].size).to be <= 5
      expect(response_body["pagination"]["per_page"]).to eq(5)
    end

    it "enforces maximum per_page limit" do
      get "/api/users?per_page=200", headers: { 'Authorization' => admin_token }

      response_body = JSON.parse(response.body)
      expect(response_body["pagination"]["per_page"]).to eq(100) # Max enforced
    end

    it "calculates total pages correctly" do
      get "/api/users?per_page=10", headers: { 'Authorization' => admin_token }

      response_body = JSON.parse(response.body)
      total_count = response_body["pagination"]["total_count"]
  per_page = response_body["pagination"]["per_page"]
  expected_pages = (total_count.to_f / per_page).ceil
  expect(response_body["pagination"]["total_pages"]).to eq(expected_pages)
    end
  end
end
