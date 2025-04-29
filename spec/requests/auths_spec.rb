require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:user) { User.create(email: "test@example.com", password: "password123") }

  describe "POST /users/sign_in" do
    it "returns a JWT token when credentials are valid" do
      post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to eq("Logged in successfully.")
      expect(response.headers["Authorization"]).to be_present
    end

    it "returns an error when credentials are invalid" do
      post "/users/sign_in", params: { user: { email: user.email, password: "wrongpassword" } }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid Email or password.")
    end
  end

  describe "DELETE /users/sign_out" do
    it "revokes the JWT token" do
      # Log in to get a token
      post "/users/sign_in", params: { user: { email: user.email, password: "password123" } }
      token = response.headers["Authorization"]

      # Log out to revoke the token
      delete "/users/sign_out", headers: { "Authorization" => token }

      expect(response).to have_http_status(:no_content)
    end
  end
end
