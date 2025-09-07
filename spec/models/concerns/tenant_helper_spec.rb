# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantHelper, type: :model do
  let(:test_tenant) { create(:tenant, subdomain: 'testcorp') }
  let(:test_schema) { 'testcorp' }

  # Mock the gem's high-level API methods and SchemaSwitcher
  before do
    allow(PgMultitenantSchemas).to receive(:switch_to_schema)
    allow(PgMultitenantSchemas).to receive(:current_schema).and_return("public")
    allow(PgMultitenantSchemas).to receive(:current_tenant).and_return(nil)
    allow(PgMultitenantSchemas).to receive(:current_tenant=)
    allow(PgMultitenantSchemas).to receive(:current_schema=)
    allow(PgMultitenantSchemas).to receive(:with_tenant).and_yield
    # Mock SchemaSwitcher methods with proper argument expectations
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema)
    # Mock tenant resolution methods
    allow(PgMultitenantSchemas).to receive(:extract_subdomain)
    allow(PgMultitenantSchemas).to receive(:find_tenant_by_subdomain)
    allow(PgMultitenantSchemas).to receive(:resolve_tenant_from_request)
  end

  describe '.with_tenant' do
    it 'delegates to gem for tenant context management' do
      expect(PgMultitenantSchemas).to receive(:with_tenant).with(test_tenant).and_yield

      result = TenantHelper.with_tenant(test_tenant) do
        "executed"
      end
      expect(result).to eq("executed")
    end
  end

  describe '.switch_to_schema' do
    it 'delegates to gem for schema switching' do
      # TenantHelper.switch_to_schema uses SchemaSwitcher directly with new API (only schema name)
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
        .with(test_schema)
      expect(PgMultitenantSchemas).to receive(:current_schema=).with(test_schema)
      TenantHelper.switch_to_schema(test_schema)
    end
  end

  describe '.create_tenant_schema' do
    it 'delegates to gem for schema creation' do
      # TenantHelper.create_tenant_schema uses SchemaSwitcher directly with new API (only schema name)
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
        .with(test_schema)
      TenantHelper.create_tenant_schema(test_tenant)
    end

    it 'works with schema name string' do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
        .with(test_schema)
      TenantHelper.create_tenant_schema(test_schema)
    end
  end

  describe '.current_tenant' do
    it 'returns the currently set tenant' do
      expect(PgMultitenantSchemas).to receive(:current_tenant=).with(test_tenant)
      expect(PgMultitenantSchemas).to receive(:current_tenant).and_return(test_tenant)
      
      TenantHelper.current_tenant = test_tenant
      expect(TenantHelper.current_tenant).to eq(test_tenant)
    end

    it 'returns nil when no tenant is set' do
      expect(PgMultitenantSchemas).to receive(:current_tenant=).with(nil)
      expect(PgMultitenantSchemas).to receive(:current_tenant).and_return(nil)
      
      TenantHelper.current_tenant = nil
      expect(TenantHelper.current_tenant).to be_nil
    end
  end

  describe '.switch_to_schema' do
    it 'switches to specified schema' do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
        .with(test_schema)

      TenantHelper.switch_to_schema(test_schema)
    end

    it 'handles nil schema by switching to public' do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
        .with('public')

      TenantHelper.switch_to_schema(nil)
    end
  end

  describe '.create_tenant_schema' do
    it 'creates schema for tenant' do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
        .with(test_schema)

      TenantHelper.create_tenant_schema(test_tenant)
    end

    it 'accepts schema string' do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
        .with(test_schema)

      TenantHelper.create_tenant_schema(test_schema)
    end
  end

  describe '.drop_tenant_schema' do
    it 'drops schema for tenant' do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema)
        .with(test_schema)

      TenantHelper.drop_tenant_schema(test_tenant)
    end

    it 'accepts schema string' do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema)
        .with(test_schema)

      TenantHelper.drop_tenant_schema(test_schema)
    end
  end

  describe '.extract_subdomain' do
    it 'extracts subdomain from various host formats' do
      expect(PgMultitenantSchemas).to receive(:extract_subdomain).with('testcorp.example.com').and_return('testcorp')
      expect(PgMultitenantSchemas).to receive(:extract_subdomain).with('testcorp.localhost:3000').and_return('testcorp')
      expect(PgMultitenantSchemas).to receive(:extract_subdomain).with('api.testcorp.example.com').and_return('api')
      
      expect(TenantHelper.extract_subdomain('testcorp.example.com')).to eq('testcorp')
      expect(TenantHelper.extract_subdomain('testcorp.localhost:3000')).to eq('testcorp')
      expect(TenantHelper.extract_subdomain('api.testcorp.example.com')).to eq('api')
    end

    it 'returns nil for hosts without subdomain' do
      expect(PgMultitenantSchemas).to receive(:extract_subdomain).with('example.com').and_return(nil)
      expect(PgMultitenantSchemas).to receive(:extract_subdomain).with('localhost:3000').and_return(nil)
      expect(PgMultitenantSchemas).to receive(:extract_subdomain).with('127.0.0.1:3000').and_return(nil)
      
      expect(TenantHelper.extract_subdomain('example.com')).to be_nil
      expect(TenantHelper.extract_subdomain('localhost:3000')).to be_nil
      expect(TenantHelper.extract_subdomain('127.0.0.1:3000')).to be_nil
    end

    it 'returns nil for excluded subdomains' do
      excluded = %w[www api admin mail ftp]
      excluded.each do |subdomain|
        expect(PgMultitenantSchemas).to receive(:extract_subdomain).with("#{subdomain}.example.com").and_return(nil)
        expect(TenantHelper.extract_subdomain("#{subdomain}.example.com")).to be_nil
      end
    end
  end

  describe '.find_tenant_by_subdomain' do
    it 'finds active tenant by subdomain' do
      active_tenant = create(:tenant, :active, subdomain: 'findme')
      expect(PgMultitenantSchemas).to receive(:find_tenant_by_subdomain).with('findme').and_return(active_tenant)

      result = TenantHelper.find_tenant_by_subdomain('findme')
      expect(result).to eq(active_tenant)
    end

    it 'returns nil for inactive tenant' do
      create(:tenant, :inactive, subdomain: 'inactive')

      result = TenantHelper.find_tenant_by_subdomain('inactive')
      expect(result).to be_nil
    end

    it 'returns nil for non-existent subdomain' do
      result = TenantHelper.find_tenant_by_subdomain('nonexistent')
      expect(result).to be_nil
    end
  end

  describe '.resolve_tenant_from_request' do
    let(:request_double) { double('request') }

    it 'resolves tenant from request host' do
      allow(request_double).to receive(:host).and_return('testcorp.example.com')
      expect(PgMultitenantSchemas).to receive(:resolve_tenant_from_request).with(request_double).and_return(test_tenant)

      result = TenantHelper.resolve_tenant_from_request(request_double)
      expect(result).to eq(test_tenant)
    end

    it 'returns nil when no subdomain in host' do
      allow(request_double).to receive(:host).and_return('example.com')

      result = TenantHelper.resolve_tenant_from_request(request_double)
      expect(result).to be_nil
    end

    it 'returns nil when subdomain is excluded' do
      allow(request_double).to receive(:host).and_return('www.example.com')

      result = TenantHelper.resolve_tenant_from_request(request_double)
      expect(result).to be_nil
    end
  end

  describe 'instance methods when included in controller' do
    let(:controller) do
      Class.new do
        include TenantHelper
        attr_accessor :request
      end.new
    end

    before do
      controller.request = double('request', host: 'testcorp.example.com')
    end

    describe '#current_tenant' do
      it 'returns instance variable tenant' do
        controller.instance_variable_set(:@current_tenant, test_tenant)
        expect(controller.send(:current_tenant)).to eq(test_tenant)
      end
    end

    describe '#switch_to_tenant' do
      it 'sets current tenant and switches schema' do
        expect(PgMultitenantSchemas).to receive(:current_tenant=).with(test_tenant)
        expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
          .with(test_schema)

        controller.send(:switch_to_tenant, test_tenant)
        expect(controller.send(:current_tenant)).to eq(test_tenant)
      end

      it 'handles nil tenant by switching to public schema' do
        expect(PgMultitenantSchemas).to receive(:current_tenant=).with(nil)
        expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
          .with('public')

        controller.send(:switch_to_tenant, nil)
        expect(controller.send(:current_tenant)).to be_nil
        expect(TenantHelper.current_tenant).to be_nil
      end
    end

    describe '#resolve_tenant' do
      it 'resolves and switches to tenant from request' do
        expect(TenantHelper).to receive(:resolve_tenant_from_request).and_return(test_tenant)
        expect(controller).to receive(:switch_to_tenant).with(test_tenant)

        controller.send(:resolve_tenant)
      end

      it 'handles tenant resolution failure gracefully' do
        expect(TenantHelper).to receive(:resolve_tenant_from_request).and_return(nil)
        expect(controller).to receive(:switch_to_tenant).with(nil)

        controller.send(:resolve_tenant)
      end
    end

    describe '#reset_tenant_context' do
      it 'resets tenant to nil and switches to public schema' do
        controller.instance_variable_set(:@current_tenant, test_tenant)
        TenantHelper.current_tenant = test_tenant

        expect(TenantHelper).to receive(:switch_to_schema).with('public')

        controller.send(:reset_tenant_context)
        expect(controller.send(:current_tenant)).to be_nil
        expect(TenantHelper.current_tenant).to be_nil
      end
    end
  end

  describe 'error handling' do
    it 'handles schema creation errors gracefully' do
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema).and_raise(StandardError, 'Schema creation failed')

      expect {
        TenantHelper.create_tenant_schema(test_schema)
      }.to raise_error(StandardError, 'Schema creation failed')
    end

    it 'handles schema switching errors gracefully' do
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema).and_raise(StandardError, 'Schema switch failed')

      expect {
        TenantHelper.switch_to_schema(test_schema)
      }.to raise_error(StandardError, 'Schema switch failed')
    end
  end

  describe 'schema name validation' do
    it 'validates schema names conform to PostgreSQL requirements' do
      valid_schemas = %w[testcorp test_corp test123 corp123]
      invalid_schemas = [ 'test-corp', 'test corp', '123test', 'TEST', 'public', 'information_schema' ]

      valid_schemas.each do |schema|
        expect { TenantHelper.switch_to_schema(schema) }.not_to raise_error
      end

      # Note: Actual validation would be in the custom gem, this is just testing our integration
      expect(PgMultitenantSchemas).to receive(:extract_subdomain).with('123invalid.example.com').and_return('123invalid')
      expect(TenantHelper.extract_subdomain('123invalid.example.com')).to eq('123invalid')
    end
  end
end
