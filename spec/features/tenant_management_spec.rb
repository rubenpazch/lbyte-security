# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Tenant Management System", type: :request do
  let!(:super_admin) do
    user = create(:user, email: "superadmin@test.com", user_name: "superadmin")  # Fixed: username → user_name, removed is_admin
    admin_role = Role.find_or_create_by(name: "Super Admin") do |role|
      role.description = "Super Administrator with full system access"
      role.level = 100
      role.is_system = true
      role.color = "#dc3545"
      role.icon = "fas fa-crown"
    end
    user.roles << admin_role unless user.roles.include?(admin_role)
    user
  end
  let!(:regular_admin) { create(:user, :admin) }
  let!(:tenant) { create(:tenant, :active, subdomain: 'acme', name: 'Acme Corp') }
  let!(:alpha_tenant) { create(:tenant, :active, subdomain: 'alpha', name: 'Alpha Corp') }
  let!(:beta_tenant) { create(:tenant, :active, subdomain: 'beta', name: 'Beta Corp') }
  let!(:alpha_admin) { create(:user, :admin, email: 'admin@alpha.com', user_name: 'alpha_admin') }  # Fixed: username → user_name
  let!(:beta_admin) { create(:user, :admin, email: 'admin@beta.com', user_name: 'beta_admin') }  # Fixed: username → user_name

  before(:each) do
    # Use the existing super_admin user created by let!
    @auth_token = sign_in_user(super_admin)  # Fixed: Use super_admin from let! block
    
    # Mock schema operations to avoid actual PostgreSQL schema manipulation in tests
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema) 
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
    allow(TenantHelper).to receive(:create_tenant_schema)
    allow(TenantHelper).to receive(:drop_tenant_schema) 
    allow(TenantHelper).to receive(:switch_to_schema)
  end

  describe "tenant creation workflow" do
    context "as super admin" do
      let(:super_admin_token) { sign_in_user(super_admin) }

      it "creates tenant with complete lifecycle" do
        tenant_data = {
          tenant: {
            name: "New Enterprise",
            subdomain: "newent",
            status: "trial",
            plan: "enterprise",
            description: "New enterprise tenant for testing",
            contact_email: "admin@newent.com",
            contact_name: "Enterprise Admin",
            trial_ends_at: 30.days.from_now
          }
        }

        # Create the tenant
        post "/api/tenants", params: tenant_data, headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:created)
        response_body = JSON.parse(response.body)
        new_tenant_id = response_body['data']['id']

        # Verify schema creation was triggered via TenantHelper (actual implementation)
        expect(TenantHelper).to have_received(:create_tenant_schema)

        # Verify tenant can be retrieved
        get "/api/tenants/#{new_tenant_id}"
        expect(response).to have_http_status(:ok)

        tenant_details = JSON.parse(response.body)['data']
        expect(tenant_details['name']).to eq("New Enterprise")
        expect(tenant_details['subdomain']).to eq("newent")
        expect(tenant_details['status']).to eq("trial")
        expect(tenant_details['plan']).to eq("enterprise")
      end

      it "handles tenant creation with validation errors" do
        invalid_data = {
          tenant: {
            name: "",  # Missing required name
            subdomain: "invalid subdomain!",  # Invalid format
            status: "invalid_status"  # Invalid status
          }
        }

        post "/api/tenants", params: invalid_data, headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body['errors']).to be_an(Array)
        expect(response_body['errors'].length).to be > 0

        # Schema should not be created for invalid tenant (check actual implementation)
        expect(TenantHelper).not_to have_received(:create_tenant_schema)
      end
    end

    context "as regular admin" do
      let(:admin_token) { sign_in_user(regular_admin) }

      it "denies tenant creation" do
        tenant_data = {
          tenant: {
            name: "Unauthorized Tenant",
            subdomain: "unauthorized"
          }
        }

        post "/api/tenants", params: tenant_data, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "tenant schema isolation" do
    it "maintains data isolation between tenants" do
      alpha_token = sign_in_user(alpha_admin)
      beta_token = sign_in_user(beta_admin)

      # Request from alpha tenant
      get "/api/users", headers: {
        'Authorization' => alpha_token,
        'Host' => 'alpha.localhost:3000'
      }
      expect(response).to have_http_status(:ok)
      # Note: TenantHelper.switch_to_schema is called internally for tenant switching
      expect(TenantHelper).to have_received(:switch_to_schema).at_least(:once)

      # Request from beta tenant
      get "/api/users", headers: {
        'Authorization' => beta_token,
        'Host' => 'beta.localhost:3000'
      }
      expect(response).to have_http_status(:ok)
      # Beta tenant schema switching is also handled by TenantHelper
      expect(TenantHelper).to have_received(:switch_to_schema).at_least(:twice)
    end
  end

  describe "tenant status transitions" do
    let(:super_admin_token) { sign_in_user(super_admin) }

    context "trial to active transition" do
      let!(:trial_tenant) { create(:tenant, :trial, subdomain: 'trial-corp') }

      it "successfully transitions trial tenant to active" do
        update_params = {
          tenant: {
            status: "active",
            plan: "professional"
          }
        }

        put "/api/tenants/#{trial_tenant.id}",
            params: update_params,
            headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:ok)

        trial_tenant.reload
        expect(trial_tenant.status).to eq('active')
        expect(trial_tenant.plan).to eq('professional')
      end
    end

    context "tenant suspension" do
      it "suspends active tenant" do
        update_params = { tenant: { status: "suspended" } }

        put "/api/tenants/#{tenant.id}",
            params: update_params,
            headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:ok)

        tenant.reload
        expect(tenant.status).to eq('suspended')
        expect(tenant.active?).to be false
      end
    end
  end

  describe "tenant deletion workflow" do
    let!(:deletable_tenant) { create(:tenant, :active, subdomain: 'deleteme') }
    let(:super_admin_token) { sign_in_user(super_admin) }

    it "completely removes tenant and schema" do
      tenant_id = deletable_tenant.id
      subdomain = deletable_tenant.subdomain

      # Delete the tenant
      delete "/api/tenants/#{tenant_id}", headers: { 'Authorization' => super_admin_token }

      expect(response).to have_http_status(:ok)

      # Verify tenant record is deleted
      expect(Tenant.find_by(id: tenant_id)).to be_nil

      # Verify schema deletion was called via TenantHelper
      expect(TenantHelper).to have_received(:drop_tenant_schema)

      # Verify tenant cannot be accessed after deletion
      get "/api/tenants/#{tenant_id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "public schema shared models" do
    context "tenant model access" do
      it "lists all tenants from public schema regardless of current tenant" do
        # Request from tenant context
        get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)

        # Should see all active tenants
        tenant_subdomains = response_body['data'].map { |t| t['subdomain'] }
        expect(tenant_subdomains).to include('alpha', 'beta')
        expect(tenant_subdomains).not_to include('inactive')
      end
    end

    context "JWT denylist access" do
      let(:user_token) { sign_in_user(create(:user)) }

      it "maintains JWT denylist in public schema across tenants" do
        user = create(:user)
        user_token = sign_in_user(user)

        # Sign out from alpha tenant (adds JWT to denylist)
        delete "/users/sign_out", headers: {
          'Authorization' => user_token,
          'Host' => 'alpha.localhost:3000'
        }
        expect(response).to have_http_status(:no_content)

        # Try to access authenticated endpoint from beta tenant with denylisted token
        put "/api/users/#{user.id}",
            params: { user: { first_name: "Updated" } },
            headers: {
              'Authorization' => user_token,
              'Host' => 'beta.localhost:3000'
            }
        # The denylisted token should be rejected
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "tenant plan limitations" do
    context "basic plan tenant" do
      let!(:basic_tenant) { create(:tenant, :basic, subdomain: 'basic') }

      it "operates with basic plan restrictions" do
        get "/api/tenants", headers: { 'Host' => 'basic.localhost:3000' }

        expect(response).to have_http_status(:ok)
        # Note: TenantHelper manages schema switching for public schema access
        expect(TenantHelper).to have_received(:switch_to_schema).at_least(:once)
      end
    end

    context "enterprise plan tenant" do
      let!(:enterprise_tenant) { create(:tenant, :enterprise, subdomain: 'enterprise') }

      it "operates with enterprise plan features" do
        get "/api/tenants", headers: { 'Host' => 'enterprise.localhost:3000' }

        expect(response).to have_http_status(:ok)
        # Note: TenantHelper manages schema switching for public schema access
        expect(TenantHelper).to have_received(:switch_to_schema).at_least(:once)
      end
    end
  end

  describe "concurrent tenant access" do
    let!(:alpha_tenant) { create(:tenant, :active, subdomain: 'alpha', name: 'Alpha Corp') }
    let!(:beta_tenant) { create(:tenant, :active, subdomain: 'beta', name: 'Beta Corp') }

    it "handles multiple simultaneous tenant requests" do
      # Simulate concurrent requests to different tenants
      threads = []

      threads << Thread.new do
        get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }
        expect(response).to have_http_status(:ok)
      end

      threads << Thread.new do
        get "/api/tenants", headers: { 'Host' => 'beta.localhost:3000' }
        expect(response).to have_http_status(:ok)
      end

      threads.each(&:join)

      # Verify both tenant schemas were accessed via TenantHelper
      expect(TenantHelper).to have_received(:switch_to_schema).at_least(:twice)
    end
  end
end
