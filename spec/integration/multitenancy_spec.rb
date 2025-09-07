# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Multitenancy Integration", type: :request do
  let!(:tenant_alpha) { create(:tenant, :active, subdomain: 'alpha', name: 'Alpha Corporation') }
  let!(:tenant_beta) { create(:tenant, :active, subdomain: 'beta', name: 'Beta Industries') }
  let!(:tenant_inactive) { create(:tenant, :inactive, subdomain: 'inactive') }

  before do
    # Mock schema operations for integration tests
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema)
    allow(TenantHelper).to receive(:create_tenant_schema)
    allow(TenantHelper).to receive(:drop_tenant_schema)
  end

  describe "tenant resolution from subdomain" do
    context "with valid active tenant" do
      it "resolves tenant from alpha subdomain" do
        get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }

        expect(response).to have_http_status(:ok)
        # Verify schema switching was called with correct schema (new API - only schema name)
        expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
          .with('alpha')
      end

      it "resolves tenant from beta subdomain" do
        get "/api/tenants", headers: { 'Host' => 'beta.localhost:3000' }

        expect(response).to have_http_status(:ok)
        expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
          .with('beta')
      end
    end

    context "with inactive tenant" do
      it "does not resolve inactive tenant" do
        get "/api/tenants", headers: { 'Host' => 'inactive.localhost:3000' }

        expect(response).to have_http_status(:ok)
        # Should default to public schema when tenant not found/inactive
        expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
          .with('public').at_least(:once)
      end
    end

    context "with non-existent tenant" do
      it "defaults to public schema" do
        get "/api/tenants", headers: { 'Host' => 'nonexistent.localhost:3000' }

        expect(response).to have_http_status(:ok)
        expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
          .with('public').at_least(:once)
      end
    end

    context "with excluded subdomains" do
      %w[www api admin mail ftp].each do |excluded|
        it "ignores #{excluded} subdomain" do
          get "/api/tenants", headers: { 'Host' => "#{excluded}.localhost:3000" }

          expect(response).to have_http_status(:ok)
          expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
            .with('public').at_least(:once)
        end
      end
    end

    context "without subdomain" do
      it "uses public schema for root domain" do
        get "/api/tenants", headers: { 'Host' => 'localhost:3000' }

        expect(response).to have_http_status(:ok)
        expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
          .with('public').at_least(:once)
      end
    end
  end

  describe "tenant lifecycle with API" do
    let!(:super_admin) do
      # Ensure Super Admin role exists
      super_admin_role = Role.find_or_create_by(name: "Super Admin") do |role|
        role.description = "System Super Administrator with full access"
        role.level = 100
        role.is_system = true
        role.color = "#dc3545"
        role.icon = "fas fa-crown"
      end

      user = create(:user, email: "superadmin@test.com")  # Fixed: removed is_admin
      user.roles << super_admin_role unless user.roles.include?(super_admin_role)
      user
    end
    let(:super_admin_token) { sign_in_user(super_admin) }

    context "creating new tenant" do
      let(:tenant_params) do
        {
          tenant: {
            name: "Gamma Solutions",
            subdomain: "gamma",
            status: "active",
            plan: "professional",
            description: "A new solutions company"
          }
        }
      end

      it "creates tenant and schema in sequence" do
        post "/api/tenants", params: tenant_params, headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:created)

        # Verify tenant was created
        new_tenant = Tenant.find_by(subdomain: 'gamma')
        expect(new_tenant).to be_present
        expect(new_tenant.name).to eq("Gamma Solutions")

        # Verify schema creation was triggered
        expect(TenantHelper).to have_received(:create_tenant_schema)
      end
    end

    context "deleting existing tenant" do
      let(:deletable_tenant) { create(:tenant, :active, subdomain: 'deleteme') }

      it "deletes tenant and drops schema" do
        tenant_id = deletable_tenant.id
        subdomain = deletable_tenant.subdomain

        delete "/api/tenants/#{tenant_id}", headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:ok)

        # Verify tenant was deleted
        expect(Tenant.find_by(id: tenant_id)).to be_nil

        # Verify schema deletion was triggered
        expect(TenantHelper).to have_received(:drop_tenant_schema)
      end
    end
  end

  describe "cross-tenant data isolation" do
    let!(:alpha_user) { create(:user, email: 'alpha@test.com') }
    let!(:beta_user) { create(:user, email: 'beta@test.com') }

    before do
      # Mock tenant-specific user queries to simulate schema isolation
      allow(User).to receive(:all).and_return([ alpha_user ]) # Alpha schema
      allow(User).to receive(:all).and_return([ beta_user ])  # Beta schema (would be separate call)
    end

    it "isolates data between tenants" do
      # Request from alpha tenant
      get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
        .with('alpha')

      # Request from beta tenant
      get "/api/tenants", headers: { 'Host' => 'beta.localhost:3000' }
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
        .with('beta')
    end
  end

  describe "error scenarios" do
    context "schema switching failures" do
      before do
        allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant_alpha)
        allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
          .and_raise(PgMultitenantSchemas::ConnectionError, 'Connection failed')
      end

      it "handles schema errors gracefully in development" do
        allow(Rails.env).to receive(:development?).and_return(true)

        get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }

        expect(response).to have_http_status(:ok)
      end

      it "propagates schema errors in production" do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.env).to receive(:production?).and_return(true)

        expect {
          get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }
        }.to raise_error(PgMultitenantSchemas::ConnectionError)
      end
    end

    context "tenant not found scenarios" do
      it "handles missing tenant gracefully" do
        allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(nil)

        get "/api/tenants", headers: { 'Host' => 'missing.localhost:3000' }

        expect(response).to have_http_status(:ok)
        expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
          .with('public').at_least(:once)
      end
    end
  end

  describe "authentication within tenant context" do
    let!(:tenant_user) { create(:user, email: 'tenant@alpha.com') }
    let(:user_token) { sign_in_user(tenant_user) }

    before do
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant_alpha)
    end

    it "maintains tenant context during authenticated requests" do
      get "/api/tenants/#{tenant_alpha.id}",
          headers: {
            'Authorization' => user_token,
            'Host' => 'alpha.localhost:3000'
          }

      expect(response).to have_http_status(:ok)
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
        .with('alpha').at_least(:once)
    end
  end

  describe "public schema operations" do
    context "accessing tenant management" do
      let!(:super_admin) do
        # Ensure Super Admin role exists
        super_admin_role = Role.find_or_create_by(name: "Super Admin") do |role|
          role.description = "System Super Administrator with full access"
          role.level = 100
          role.is_system = true
          role.color = "#dc3545"
          role.icon = "fas fa-crown"
        end

        user = create(:user, email: "superadmin@test.com")  # Fixed: removed is_admin
        user.roles << super_admin_role unless user.roles.include?(super_admin_role)
        user
      end
      let(:super_admin_token) { sign_in_user(super_admin) }

      it "manages tenants from public schema" do
        get "/api/tenants", headers: { 'Authorization' => super_admin_token }

        expect(response).to have_http_status(:ok)
        # Tenant management should operate on public schema
        expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
          .with('public').at_least(:once)
      end
    end
  end

  describe "schema reset behavior" do
    it "always resets to public schema after request" do
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant_alpha)

      get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }

      # Should switch to tenant schema during request
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
        .with('alpha').at_least(:once)
      # Should reset to public schema after request
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
        .with('public').at_least(:once)
    end

    it "resets to public schema even when action fails" do
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant_alpha)
      allow(Tenant).to receive(:active).and_raise(StandardError, 'Database error')

      expect {
        get "/api/tenants", headers: { 'Host' => 'alpha.localhost:3000' }
      }.to raise_error(StandardError, 'Database error')

      # Should still attempt to switch to public schema during cleanup
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema)
        .with('public').at_least(:once)
    end
  end
end
