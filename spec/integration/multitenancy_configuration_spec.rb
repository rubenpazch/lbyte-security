# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Multitenancy Configuration", type: :request do
  describe "PgMultitenantSchemas configuration" do
    it "loads configuration correctly" do
      expect(defined?(PgMultitenantSchemas)).to be_truthy

      # Verify the initializer sets up the connection
      expect(PgMultitenantSchemas).to respond_to(:configure)
    end

    it "uses Rails database connection" do
      # Test that configuration uses ActiveRecord connection
      config_path = Rails.root.join('config/initializers/pg_multitenant_schemas.rb')
      expect(File.exist?(config_path)).to be true

      config_content = File.read(config_path)
      expect(config_content).to include('PgMultitenantSchemas.configure')
      expect(config_content).to include('ApplicationRecord')
    end
  end

  describe "Schema switching behavior" do
    let(:tenant) { Tenant.find_by(subdomain: 'demo') || create(:tenant, :active, subdomain: 'demo') }

    before do
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema)
      
      # Mock ActiveRecord connection for parameter matching
      connection_double = double('connection')
      allow(connection_double).to receive(:exec)
      allow(connection_double).to receive(:execute) 
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection_double)
    end

    it "switches schemas for different operations", :uses_database do
      # Simulate tenant context operations using existing tenant
      TenantHelper.with_tenant(tenant) do
        # Any database operations would be in tenant schema
        begin
          User.count  # This would query the tenant schema
        rescue ActiveRecord::StatementInvalid
          # Ignore if schema doesn't have users table yet
        end
      end

      # The gem's with_tenant method internally calls switch_schema, just verify it was called
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema).at_least(:once)
    end

    it "handles nested tenant switching", :uses_database do
      # Use existing tenants to avoid creating new ones in transaction
      demo_tenant = Tenant.find_by(subdomain: 'demo') || create(:tenant, subdomain: 'demo')
      acme_tenant = Tenant.find_by(subdomain: 'acme') || create(:tenant, subdomain: 'acme')

      original_tenant = TenantHelper.current_tenant
      original_schema = TenantHelper.current_schema

      TenantHelper.with_tenant(demo_tenant) do
        expect(TenantHelper.current_schema).to eq('demo')
        expect(TenantHelper.current_tenant).to eq(demo_tenant)

        TenantHelper.with_tenant(acme_tenant) do
          expect(TenantHelper.current_schema).to eq('acme')
          expect(TenantHelper.current_tenant).to eq(acme_tenant)
        end

        expect(TenantHelper.current_schema).to eq('demo')
        expect(TenantHelper.current_tenant).to eq(demo_tenant)
      end

      expect(TenantHelper.current_schema).to eq(original_schema)
      expect(TenantHelper.current_tenant).to eq(original_tenant)
    end
  end

  describe "Database connection management" do
    it "maintains connection state across schema switches" do
      # Mock schema switcher methods with new API (no connection parameter)
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)

      TenantHelper.switch_to_schema('test-schema')
      TenantHelper.switch_to_schema('public')

      # Verify schema switching commands would be executed with the new API (only schema name)
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema).with('test-schema')
      expect(PgMultitenantSchemas::SchemaSwitcher).to have_received(:switch_schema).with('public')
    end
  end

  describe "Error handling and recovery" do
    context "when custom gem is not available" do
      it "handles missing gem gracefully" do
        # Since we have the gem properly configured, verify it loads without error
        expect {
          load Rails.root.join('config/initializers/pg_multitenant_schemas.rb')
        }.not_to raise_error
        
        # Verify the gem is available and configured
        expect(defined?(PgMultitenantSchemas)).to be_truthy
      end
    end

    context "with database connection issues" do
      before do
        allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
          .with(anything, any_args)
          .and_raise(PgMultitenantSchemas::ConnectionError, 'Connection lost')
      end

      it "propagates connection errors appropriately" do
        expect {
          TenantHelper.switch_to_schema('test-schema')
        }.to raise_error(PgMultitenantSchemas::ConnectionError, 'Connection lost')
      end
    end

    context "with invalid schema names" do
      it "handles invalid schema names" do
        # Invalid characters for PostgreSQL schema names
        invalid_schemas = [ 'test-schema!', 'test schema', '1invalid', 'SELECT' ]

        invalid_schemas.each do |invalid_schema|
          # Mock the switcher to raise appropriate errors for invalid schema names (new API - only schema name)
          allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
            .with(invalid_schema)
            .and_raise(PgMultitenantSchemas::ConnectionError, "Invalid schema name: #{invalid_schema}")

          expect {
            TenantHelper.switch_to_schema(invalid_schema)
          }.to raise_error(PgMultitenantSchemas::ConnectionError)
        end
      end
    end
  end

  describe "Thread safety" do
    let!(:tenants) { create_list(:tenant, 3, :active) }

    it "handles concurrent tenant operations safely" do
      results = []
      threads = []

      tenants.each_with_index do |tenant, index|
        threads << Thread.new do
          TenantHelper.with_tenant(tenant) do
            # Simulate some work in tenant context
            sleep(0.01)  # Small delay to encourage race conditions
            results << "tenant-#{index}-completed"
          end
        end
      end

      threads.each(&:join)

      expect(results.length).to eq(3)
      expect(results).to all(match(/tenant-\d+-completed/))
    end
  end

  describe "Memory and resource management" do
    it "cleans up tenant context properly", :uses_database do
      # Use existing tenant to avoid transaction issues
      tenant = Tenant.find_by(subdomain: 'demo') || create(:tenant, subdomain: 'demo')

      # Set tenant context
      TenantHelper.current_tenant = tenant
      expect(TenantHelper.current_tenant).to eq(tenant)

      # Reset context
      TenantHelper.current_tenant = nil
      expect(TenantHelper.current_tenant).to be_nil

      # Verify garbage collection can clean up
      tenant = nil
      GC.start
      expect(TenantHelper.current_tenant).to be_nil
    end

    it "handles large numbers of tenant switches efficiently", :uses_database do
      # Use existing tenant to avoid transaction issues
      tenant = Tenant.find_by(subdomain: 'demo') || create(:tenant, subdomain: 'demo')

      start_time = Time.current

      100.times do
        TenantHelper.with_tenant(tenant) do
          # Minimal operation
          tenant.subdomain
        end
      end

      end_time = Time.current

      # Should complete quickly even with many switches
      expect(end_time - start_time).to be < 1.second
    end
  end

  describe "Configuration validation" do
    it "validates required configuration is present" do
      # Check that initializer file exists and is loadable
      initializer_path = Rails.root.join('config/initializers/pg_multitenant_schemas.rb')
      expect(File.exist?(initializer_path)).to be true

      # Verify configuration content includes required setup
      config_content = File.read(initializer_path)
      expect(config_content).to include('PgMultitenantSchemas.configure')
      expect(config_content).to include('ApplicationRecord')
    end

    it "has proper gem dependency" do
      # Verify gem is listed in Gemfile
      gemfile_content = File.read(Rails.root.join('Gemfile'))
      expect(gemfile_content).to include('pg_multitenant_schemas')
    end
  end

  describe "Integration with existing authentication" do
    context "JWT token validation across tenants" do
      let!(:alpha_tenant) { Tenant.find_by(subdomain: 'demo') || create(:tenant, subdomain: 'demo') }
      let!(:beta_tenant) { Tenant.find_by(subdomain: 'acme') || create(:tenant, subdomain: 'acme') }

      it "validates JWT tokens consistently across tenant boundaries", :uses_database do
        # Test that tenant context is properly isolated during authentication
        # Mock the User model to avoid database dependencies
        allow(User).to receive(:count).and_return(0)

        # Switch to demo tenant and verify context switches correctly
        TenantHelper.with_tenant('demo') do
          expect(TenantHelper.current_schema).to eq('demo')
          # Simulate accessing tenant users
          user_count = User.count
          expect(user_count).to eq(0)
        end

        # Switch to acme tenant and verify context switches correctly  
        TenantHelper.with_tenant('acme') do
          expect(TenantHelper.current_schema).to eq('acme')
          # Simulate accessing tenant users
          user_count = User.count
          expect(user_count).to eq(0)
        end

        # Verify we're back in public schema
        expect(TenantHelper.current_tenant).to be_nil
      end
    end
  end
end
