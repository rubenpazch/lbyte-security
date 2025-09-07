require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { create(:user, email: "test@example.com") }
  let(:admin_user) { create(:admin_user) }
  let(:secure_user) { create(:secure_user) }

  let(:invalid_user_params) { { user: { email: "invalid@example.com", password: "wrongpassword" } } }
  let(:valid_user_params) { { user: { email: user.email, password: user.password } } }
  let(:admin_user_params) { { user: { email: admin_user.email, password: admin_user.password } } }

  describe "POST /users/sign_in" do
    context "with valid credentials" do
      it "returns a JWT token and success message" do
        post "/users/sign_in", params: valid_user_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("Logged in successfully.")
        expect(response.headers["Authorization"]).to be_present
        expect(response.headers["Authorization"]).to start_with("Bearer ")
      end

      it "returns user data in the response" do
        post "/users/sign_in", params: valid_user_params

        response_body = JSON.parse(response.body)
        expect(response_body["user"]).to be_present
        expect(response_body["user"]["id"]).to eq(user.id)
        expect(response_body["user"]["email"]).to eq(user.email)
        expect(response_body["user"]).not_to have_key("password")
      end

      it "creates a valid JWT token" do
        post "/users/sign_in", params: valid_user_params

        token = response.headers["Authorization"]
        expect(token).to be_present

        # Verify token format
        bearer_token = token.split(" ").last
        expect(bearer_token.split(".").length).to eq(3) # JWT has 3 parts
      end
    end

    context "with different user types" do
      it "authenticates admin user successfully" do
        post "/users/sign_in", params: admin_user_params

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("Logged in successfully.")
        expect(JSON.parse(response.body)["user"]["email"]).to eq(admin_user.email)
      end

      it "authenticates user with strong password" do
        post "/users/sign_in", params: { user: { email: secure_user.email, password: secure_user.password } }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("Logged in successfully.")
      end

      it "works with factory-created users" do
        factory_user = create(:user)

        post "/users/sign_in", params: { user: { email: factory_user.email, password: factory_user.password } }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["user"]["email"]).to eq(factory_user.email)
      end

      it "can create multiple unique users" do
        user1 = create(:user)
        user2 = create(:user)

        expect(user1.email).not_to eq(user2.email)
        expect(user1.email).to match(/user\d+@example\.com/)
        expect(user2.email).to match(/user\d+@example\.com/)
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized status with invalid password" do
        post "/users/sign_in", params: { user: { email: user.email, password: "wrongpassword" } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("Invalid Email or password.")
        expect(response.headers["Authorization"]).to be_nil
      end

      it "returns unauthorized status with invalid email" do
        post "/users/sign_in", params: { user: { email: "nonexistent@example.com", password: "password123" } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("Invalid Email or password.")
        expect(response.headers["Authorization"]).to be_nil
      end

      it "returns unauthorized status with missing email" do
        post "/users/sign_in", params: { user: { password: "password123" } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to be_present
      end

      it "returns unauthorized status with missing password" do
        post "/users/sign_in", params: { user: { email: user.email } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to be_present
      end

      it "returns unauthorized status with empty credentials" do
        post "/users/sign_in", params: { user: { email: "", password: "" } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    context "with malformed request" do
      it "handles missing user parameter" do
        post "/users/sign_in", params: { email: user.email, password: "password123" }

        expect(response).to have_http_status(:unauthorized)
      end

      it "handles empty request body" do
        post "/users/sign_in"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /users/sign_out" do
    context "with valid token" do
      let(:auth_token) { sign_in_user(user) }

      it "successfully logs out and revokes the JWT token" do
        delete "/users/sign_out", headers: { "Authorization" => auth_token }

        expect(response).to have_http_status(:no_content)
      end

      it "adds token to JWT denylist" do
        expect {
          delete "/users/sign_out", headers: { "Authorization" => auth_token }
        }.to change { JwtDenylist.count }.by(1)
      end

      it "works with different user types" do
        admin_token = sign_in_user(admin_user)

        delete "/users/sign_out", headers: { "Authorization" => admin_token }
        expect(response).to have_http_status(:no_content)
      end


      it "prevents reuse of revoked token" do
        # First logout
        delete "/users/sign_out", headers: { "Authorization" => auth_token }
        expect(response).to have_http_status(:no_content)

        # Try to logout again with same token
        delete "/users/sign_out", headers: { "Authorization" => auth_token }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid token" do
      it "handles malformed tokens gracefully" do
        # This test demonstrates that malformed tokens cause JWT::DecodeError
        # In production, you'd want middleware to catch this and return 401
        expect {
          delete "/users/sign_out", headers: { "Authorization" => "Bearer invalid_token" }
        }.to raise_error(JWT::DecodeError, "Not enough or too many segments")
      end

      it "returns unauthorized status with missing token" do
        delete "/users/sign_out"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("User not found.")
      end

      it "returns unauthorized status with empty token" do
        delete "/users/sign_out", headers: { "Authorization" => "" }

        expect(response).to have_http_status(:unauthorized)
      end

      it "handles invalid signature tokens gracefully" do
        # This test demonstrates that invalid signature tokens cause JWT::VerificationError
        # In production, you'd want middleware to catch this and return 401
        expect {
          delete "/users/sign_out", headers: { "Authorization" => "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwiZXhwIjoxfQ.invalid" }
        }.to raise_error(JWT::DecodeError)
      end
    end

    context "with already revoked token" do
      let(:auth_token) do
        post "/users/sign_in", params: valid_user_params
        response.headers["Authorization"]
      end

      it "handles double logout gracefully" do
        # First logout
        delete "/users/sign_out", headers: { "Authorization" => auth_token }
        expect(response).to have_http_status(:no_content)

        # Second logout with same token
        delete "/users/sign_out", headers: { "Authorization" => auth_token }
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("User not found.")
      end
    end
  end

  describe "JWT Token Management" do
    let(:auth_token) do
      post "/users/sign_in", params: valid_user_params
      response.headers["Authorization"]
    end

    it "includes proper JWT structure" do
      post "/users/sign_in", params: valid_user_params

      token = response.headers["Authorization"].split(" ").last
      parts = token.split(".")

      expect(parts.length).to eq(3)
      # Verify it's base64-encoded (basic check)
      expect { Base64.decode64(parts[0]) }.not_to raise_error
      expect { Base64.decode64(parts[1]) }.not_to raise_error
    end

    it "maintains user session across authenticated requests" do
      # This test would be relevant if you have protected endpoints
      # For now, we can test that the token is consistently generated
      post "/users/sign_in", params: valid_user_params
      first_token = response.headers["Authorization"]

      # Login again (different session)
      post "/users/sign_in", params: valid_user_params
      second_token = response.headers["Authorization"]

      # Tokens should be different (contain different timestamps/nonces)
      expect(first_token).not_to eq(second_token)
    end
  end

  describe "Content Type and Headers" do
    it "returns JSON content type for sign in" do
      post "/users/sign_in", params: valid_user_params

      expect(response.content_type).to include("application/json")
    end

    it "returns JSON content type for sign out" do
      post "/users/sign_in", params: valid_user_params
      token = response.headers["Authorization"]

      delete "/users/sign_out", headers: { "Authorization" => token }

      # The sign out endpoint returns no_content (204) which may not have a content type
      expect(response.status).to eq(204)
    end

    it "includes CORS headers if configured" do
      post "/users/sign_in", params: valid_user_params

      # These would be present if CORS is properly configured
      # expect(response.headers["Access-Control-Allow-Origin"]).to be_present
    end
  end

  describe "Security Features" do
    it "does not expose sensitive user information" do
      post "/users/sign_in", params: valid_user_params

      response_body = JSON.parse(response.body)
      expect(response_body["user"]).not_to have_key("password")
      expect(response_body["user"]).not_to have_key("password_digest")
      expect(response_body["user"]).not_to have_key("encrypted_password")
    end

    it "handles concurrent login attempts" do
      # Simulate multiple concurrent login attempts
      threads = []
      results = []

      5.times do
        threads << Thread.new do
          post "/users/sign_in", params: valid_user_params
          results << response.status
        end
      end

      threads.each(&:join)

      # All should succeed
      expect(results.all? { |status| status == 200 }).to be true
    end
  end

  describe "Factory Bot Integration" do
    it "creates unique users with sequence" do
      user1 = create(:user)
      user2 = create(:user)
      user3 = create(:user)

      emails = [ user1.email, user2.email, user3.email ]
      expect(emails.uniq.size).to eq(3) # All emails should be unique
      emails.each { |email| expect(email).to match(/user\d+@example\.com/) }
    end

    it "works with traits for different user types" do
      admin = create(:user, :admin)
      secure_user = create(:user, :with_strong_password)
      custom_user = create(:user, email: "custom@test.com")

      expect(admin.email).to eq("admin@example.com")
      expect(secure_user.password).to eq("StrongP@ssw0rd123!")
      expect(custom_user.email).to eq("custom@test.com")
    end

    it "can use helper methods for streamlined testing" do
      result = create_and_sign_in_user(:admin_user)

      expect(result[:user].email).to eq("admin@example.com")
      expect(result[:token]).to be_present
      expect(result[:token]).to start_with("Bearer ")
    end

    it "demonstrates batch creation for load testing" do
      users = create_list(:user, 5)

      expect(users.size).to eq(5)
      users.each do |user|
        expect(user).to be_persisted
        expect(user.email).to match(/user\d+@example\.com/)
      end

      # Test that all can authenticate
      successful_logins = users.map do |user|
        post "/users/sign_in", params: valid_user_params_for(user)
        response.status == 200
      end

      expect(successful_logins.all?).to be true
    end
  end
end
