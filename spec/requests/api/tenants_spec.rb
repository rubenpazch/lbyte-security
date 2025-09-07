# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::Tenants", type: :request do
  let!(:super_admin_user) do
    # Create super admin user for tenant management tests
    user = create(:user, email: "superadmin@test.com")  # Fixed: removed is_admin
    
    # Ensure the "Super Admin" role exists exactly as expected by the model
    super_admin_role = Role.find_or_create_by(name: "Super Admin") do |role|
      role.description = "Super Administrator with full system access"
      role.level = 100
      role.is_system = true
      role.color = "#dc3545"
      role.icon = "fas fa-crown"
    end
    
    user.add_role "Super Admin"  # Fixed: Use correct role name  
    user
  end
  
  before(:each) do
    @auth_token = sign_in_user(super_admin_user)  # Fixed: Use super_admin_user from let!
  end
  let!(:admin_user) { create(:user, :admin) }
  let!(:regular_user) { create(:user) }

  let(:super_admin_token) { sign_in_user(super_admin_user) }
  let(:admin_token) { sign_in_user(admin_user) }
  let(:regular_token) { sign_in_user(regular_user) }

  # Mock schema operations to avoid actual PostgreSQL schema manipulation in tests
  before do
    # Mock the TenantHelper methods that actually call the gem's SchemaSwitcher
    allow(TenantHelper).to receive(:create_tenant_schema)
    allow(TenantHelper).to receive(:drop_tenant_schema) 
    allow(TenantHelper).to receive(:switch_to_schema)
    allow(TenantHelper).to receive(:resolve_tenant_from_request)
    allow(PgMultitenantSchemas).to receive(:switch_to_schema)
    allow(PgMultitenantSchemas).to receive(:current_schema).and_return("public")
    # TenantHelper now delegates to the gem, so mocking gem is sufficient
  end

  describe "GET /api/tenants" do
    let!(:active_tenant) { create(:tenant, :active) }
    let!(:inactive_tenant) { create(:tenant, :inactive) }

    it "returns list of active tenants without authentication" do
      get "/api/tenants"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["status"]["code"]).to eq(200)
      expect(response_body["data"]).to be_an(Array)
      expect(response_body["data"].map { |t| t["subdomain"] }).to include(active_tenant.subdomain)
      expect(response_body["data"].map { |t| t["subdomain"] }).not_to include(inactive_tenant.subdomain)
    end
  end

  describe "GET /api/tenants/:id" do
    let(:tenant) { create(:tenant, :active) }

    it "returns tenant details" do
      get "/api/tenants/#{tenant.id}"

      expect(response).to have_http_status(:ok)
      response_body = JSON.parse(response.body)
      expect(response_body["data"]["id"]).to eq(tenant.id)
      expect(response_body["data"]["name"]).to eq(tenant.name)
      expect(response_body["data"]["subdomain"]).to eq(tenant.subdomain)
    end

    it "returns 404 for non-existent tenant" do
      get "/api/tenants/99999"

      expect(response).to have_http_status(:not_found)
      response_body = JSON.parse(response.body)
      expect(response_body["status"]["message"]).to eq("Tenant not found")
    end
  end

  describe "POST /api/tenants" do
    let(:valid_tenant_params) do
      {
        tenant: {
          name: "New Corporation",
          subdomain: "newcorp",
          status: "active",
          plan: "professional",
          description: "A new test corporation",
          contact_email: "admin@newcorp.com",
          contact_name: "New Admin"
        }
      }
    end

    let(:invalid_tenant_params) do
      {
        tenant: {
          name: "",
          subdomain: "invalid subdomain!",
          status: "invalid_status"
        }
      }
    end

    context "without authentication" do
      it "returns unauthorized error" do
        post "/api/tenants", params: valid_tenant_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with regular user authentication" do
      it "returns forbidden error" do
        post "/api/tenants", params: valid_tenant_params, headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with admin authentication (non-super)" do
      it "returns forbidden error" do
        post "/api/tenants", params: valid_tenant_params, headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with super admin authentication" do
      it "creates a new tenant with valid params" do
        expect {
          post "/api/tenants", params: valid_tenant_params, headers: { 'Authorization' => super_admin_token }
        }.to change(Tenant, :count).by(1)

        expect(response).to have_http_status(:created)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["code"]).to eq(201)
        expect(response_body["data"]["name"]).to eq("New Corporation")
        expect(response_body["data"]["subdomain"]).to eq("newcorp")

        # Verify schema creation was called via TenantHelper
        expect(TenantHelper).to have_received(:create_tenant_schema)
      end

      it "returns validation errors with invalid params" do
        post "/api/tenants", params: invalid_tenant_params, headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to be_present
        expect(response_body["errors"]).to be_an(Array)
      end

      it "handles duplicate subdomain error" do
        create(:tenant, subdomain: "existing")
        duplicate_params = valid_tenant_params.deep_dup
        duplicate_params[:tenant][:subdomain] = "existing"

        post "/api/tenants", params: duplicate_params, headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["errors"]).to include(a_string_matching(/subdomain.*already.*taken/i))
      end
    end
  end

  describe "PUT /api/tenants/:id" do
    let(:tenant) { create(:tenant, :active) }
    let(:update_params) do
      {
        tenant: {
          name: "Updated Corporation",
          description: "Updated description",
          plan: "enterprise"
        }
      }
    end

    context "with super admin authentication" do
      it "updates tenant with valid params" do
        put "/api/tenants/#{tenant.id}", params: update_params, headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["data"]["name"]).to eq("Updated Corporation")
        expect(response_body["data"]["plan"]).to eq("enterprise")

        tenant.reload
        expect(tenant.name).to eq("Updated Corporation")
      end

      it "returns validation errors with invalid params" do
        put "/api/tenants/#{tenant.id}",
            params: { tenant: { subdomain: "invalid subdomain!" } },
            headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:unprocessable_content)
        response_body = JSON.parse(response.body)
        expect(response_body["errors"]).to be_present
      end
    end

    context "with insufficient permissions" do
      it "returns forbidden for regular users" do
        put "/api/tenants/#{tenant.id}", params: update_params, headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/tenants/:id" do
    let(:tenant) { create(:tenant, :active) }

    context "with super admin authentication" do
      it "deletes tenant and drops schema" do
        tenant_id = tenant.id
        subdomain = tenant.subdomain

        delete "/api/tenants/#{tenant_id}", headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body["status"]["message"]).to eq("Tenant deleted successfully")

        # Verify tenant was deleted
        expect(Tenant.find_by(id: tenant_id)).to be_nil

        # Verify schema deletion was called via TenantHelper
        expect(TenantHelper).to have_received(:drop_tenant_schema)
      end

      it "returns 404 for non-existent tenant" do
        delete "/api/tenants/99999", headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with insufficient permissions" do
      it "returns forbidden for regular users" do
        delete "/api/tenants/#{tenant.id}", headers: { 'Authorization' => regular_token }

        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden for admin users" do
        delete "/api/tenants/#{tenant.id}", headers: { 'Authorization' => admin_token }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "tenant resolution from subdomain" do
    let(:tenant) { create(:tenant, subdomain: 'testcorp') }

    it "resolves tenant from subdomain in request" do
      # Mock the tenant resolution process
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)
      allow_any_instance_of(ApplicationController).to receive(:switch_to_tenant)

      get "/api/tenants/#{tenant.id}", headers: { 'Host' => 'testcorp.localhost:3000' }

      expect(response).to have_http_status(:ok)
    end

    it "handles missing tenant gracefully in development" do
      allow(Rails.env).to receive(:development?).and_return(true)
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(nil)

      get "/api/tenants", headers: { 'Host' => 'nonexistent.localhost:3000' }

      expect(response).to have_http_status(:ok)
    end
  end
end
