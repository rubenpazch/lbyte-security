# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Jbuilder Templates", type: :request do
  let!(:tenant) { create(:tenant, :active, subdomain: 'testcorp') }
  let!(:user) { create(:user, :admin, email: 'admin@testcorp.com') }
  let(:user_token) { sign_in_user(user) }

  before do
    # Mock schema operations
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
    allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)
  end

  describe "User Jbuilder templates" do
    describe "shared user partial" do
      it "renders complete user information with tenant context" do
        get "/api/users/#{user.id}", headers: {
          'Authorization' => user_token,
          'Host' => 'testcorp.localhost:3000'
        }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        user_data = response_body['data']

        # Verify all expected fields are present
        expect(user_data).to include(
          'id', 'email', 'username', 'user_name', 'full_name',  # Fixed: updated field names
          'status', 'email_verified', 'roles', 'role_details', 'permissions',  # Fixed: use status instead of is_admin/is_active
          'created_at', 'updated_at', 'phone', 'occupation', 'company_name', 'location', 'flag', 'activity'  # Added actual fields
        )

        # Verify full_name uses user_name when available
        expect(user_data['full_name']).to eq(user.fullname)  # Fixed: use the model's fullname method

        # Verify roles and permissions structure
        expect(user_data['roles']).to be_an(Array)
        expect(user_data['role_details']).to be_an(Array)
        expect(user_data['permissions']).to be_an(Array)
      end

      it "handles users with partial name information" do
        partial_user = create(:user, user_name: 'John')  # Fixed: use user_name instead of first_name/last_name
        partial_token = sign_in_user(partial_user)

        get "/api/users/#{partial_user.id}", headers: {
          'Authorization' => partial_token,
          'Host' => 'testcorp.localhost:3000'
        }

        expect(response).to have_http_status(:ok)
        user_data = JSON.parse(response.body)['data']

        expect(user_data['full_name']).to eq('John')  # This will now use the user_name
      end

      it "handles users with no name information" do
        no_name_user = create(:user, user_name: "")  # Use empty string instead of nil to test empty name scenario
        no_name_token = sign_in_user(no_name_user)

        get "/api/users/#{no_name_user.id}", headers: {
          'Authorization' => no_name_token,
          'Host' => 'testcorp.localhost:3000'
        }

        expect(response).to have_http_status(:ok)
        user_data = JSON.parse(response.body)['data']

        # When user_name is empty, fullname falls back to email prefix
        expected_name = no_name_user.email.split("@").first
        expect(user_data['full_name']).to eq(expected_name)
      end
    end

    describe "users index template" do
      let!(:additional_users) { create_list(:user, 3) }

      it "renders paginated users list with tenant context" do
        get "/api/users", headers: {
          'Authorization' => user_token,
          'Host' => 'testcorp.localhost:3000'
        }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)

        # Verify pagination structure
        expect(response_body).to include('data', 'pagination', 'status')
        expect(response_body['data']).to be_an(Array)
        expect(response_body['pagination']).to include('current_page', 'total_pages', 'total_count')

        # Verify each user has complete information
        response_body['data'].each do |user_data|
          expect(user_data).to include('id', 'email', 'full_name', 'roles')
        end
      end

      it "respects pagination parameters with tenant context" do
        get "/api/users?page=1&per_page=2", headers: {
          'Authorization' => user_token,
          'Host' => 'testcorp.localhost:3000'
        }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)

        expect(response_body['data'].length).to be <= 2
        expect(response_body['pagination']['current_page']).to eq(1)
      end
    end
  end

  describe "Authentication Jbuilder templates" do
    describe "session creation template" do
      it "renders user session with tenant context" do
        post "/users/sign_in", params: {
          user: { email: user.email, password: 'password123' }
        }, headers: { 'Host' => 'testcorp.localhost:3000' }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)

        # Verify session structure
        expect(response_body).to include('message', 'user')
        expect(response_body['message']).to eq('Logged in successfully.')

        user_data = response_body['user']
        expect(user_data).to include('id', 'email', 'full_name', 'roles')
      end
    end

    describe "registration template" do
      it "renders new user registration with tenant context" do
        registration_params = {
          user: {
            email: 'newuser@testcorp.com',
            password: 'password123',
            password_confirmation: 'password123',
            user_name: 'newuser',  # Fixed: use user_name instead of first_name/last_name
            occupation: 'New User'
          }
        }

        post "/users", params: registration_params, headers: { 'Host' => 'testcorp.localhost:3000' }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)

        # Verify registration response structure
        expect(response_body).to include('status', 'data')
        expect(response_body['data']).to include('user')

        user_data = response_body['data']['user']
        expect(user_data['email']).to eq('newuser@testcorp.com')
        expect(user_data['full_name']).to eq('newuser')  # Fixed: expect user_name as full_name
      end
    end
  end

  describe "Error handling in templates" do
    context "with invalid user data" do
      it "handles missing user gracefully" do
        get "/api/users/99999", headers: {
          'Authorization' => user_token,
          'Host' => 'testcorp.localhost:3000'
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with tenant-specific errors" do
      before do
        allow(TenantHelper).to receive(:resolve_tenant_from_request)
          .and_raise(StandardError, 'Tenant resolution failed')
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it "handles tenant resolution errors in templates" do
        get "/api/users", headers: {
          'Authorization' => user_token,
          'Host' => 'error.localhost:3000'
        }

        # Should still return a response (in development mode)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "Template consistency across tenant contexts" do
    let!(:tenant_beta) { create(:tenant, :active, subdomain: 'beta') }
    let!(:beta_user) { create(:user, email: 'user@beta.com') }
    let(:beta_token) { sign_in_user(beta_user) }

    it "renders consistent user structure across different tenants" do
      # Get user from alpha tenant
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)
      get "/api/users/#{user.id}", headers: {
        'Authorization' => user_token,
        'Host' => 'testcorp.localhost:3000'
      }
      alpha_response = JSON.parse(response.body)

      # Get user from beta tenant
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant_beta)
      get "/api/users/#{beta_user.id}", headers: {
        'Authorization' => beta_token,
        'Host' => 'beta.localhost:3000'
      }
      beta_response = JSON.parse(response.body)

      # Both responses should have the same structure
      expect(alpha_response['data'].keys.sort).to eq(beta_response['data'].keys.sort)
    end
  end

  describe "Performance with tenant context" do
    let!(:tenant_users) { create_list(:user, 20) }

    it "efficiently renders large user lists within tenant" do
      start_time = Time.current

      get "/api/users?per_page=20", headers: {
        'Authorization' => user_token,
        'Host' => 'testcorp.localhost:3000'
      }

      end_time = Time.current

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)

      # Verify complete rendering
      expect(response_body['data']).to be_an(Array)
      expect(response_body['data'].length).to be > 0

      # Basic performance check (should complete quickly)
      expect(end_time - start_time).to be < 2.seconds
    end
  end

  describe "Template inheritance and partials" do
    it "uses shared user partial consistently" do
      # Test users index uses shared partial
      get "/api/users", headers: {
        'Authorization' => user_token,
        'Host' => 'testcorp.localhost:3000'
      }
      index_response = JSON.parse(response.body)

      # Test users show uses shared partial
      get "/api/users/#{user.id}", headers: {
        'Authorization' => user_token,
        'Host' => 'testcorp.localhost:3000'
      }
      show_response = JSON.parse(response.body)

      # User structure should be consistent between index and show
      index_user = index_response['data'].first
      show_user = show_response['data']

      # Same fields should be present (though values may differ)
      expect(index_user.keys.sort).to eq(show_user.keys.sort)
    end
  end
end
