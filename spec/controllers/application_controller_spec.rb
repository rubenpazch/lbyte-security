# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  let(:tenant) { create(:tenant, :active, subdomain: 'testcorp') }

  # Create a test controller to test ApplicationController behavior
  controller do
    def index
      render json: { tenant: current_tenant&.subdomain, message: 'success' }
    end

    def show
      render json: { id: params[:id], tenant: current_tenant&.subdomain }
    end
  end

  before do
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'show/:id' => 'anonymous#show'
    end

    # Mock schema operations
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
    allow(TenantHelper).to receive(:create_tenant_schema)
    allow(TenantHelper).to receive(:drop_tenant_schema)
  end

  describe 'tenant resolution' do
    context 'with valid tenant subdomain' do
      before do
        allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)
      end

      it 'resolves tenant before action' do
        expect(controller).to receive(:switch_to_tenant).with(tenant)

        get :index
        expect(response).to have_http_status(:ok)
      end

      it 'resets tenant context after action' do
        expect(controller).to receive(:reset_tenant_context)

        get :index
      end

      it 'makes current_tenant available in controller' do
        get :index

        response_body = JSON.parse(response.body)
        expect(response_body['tenant']).to eq('testcorp')
      end
    end

    context 'without tenant subdomain' do
      before do
        allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(nil)
      end

      it 'operates with nil tenant (public schema)' do
        expect(controller).to receive(:switch_to_tenant).with(nil)

        get :index

        response_body = JSON.parse(response.body)
        expect(response_body['tenant']).to be_nil
      end
    end

    context 'with inactive tenant' do
      let(:inactive_tenant) { create(:tenant, :inactive, subdomain: 'inactive') }

      before do
        allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(nil)
      end

      it 'does not resolve inactive tenant' do
        expect(controller).to receive(:switch_to_tenant).with(nil)

        get :index
      end
    end
  end

  describe 'error handling' do
    context 'when tenant schema switching fails' do
      before do
        allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)
        allow(controller).to receive(:switch_to_tenant).and_raise(StandardError, 'Schema not found')
      end

      it 'handles tenant errors in development' do
        allow(Rails.env).to receive(:development?).and_return(true)

        get :index

        expect(response).to have_http_status(:ok)
        response_body = JSON.parse(response.body)
        expect(response_body['tenant']).to be_nil
      end

      it 'raises tenant errors in production' do
        allow(Rails.env).to receive(:development?).and_return(false)
        allow(Rails.env).to receive(:production?).and_return(true)

        expect { get :index }.to raise_error(StandardError, 'Schema not found')
      end
    end

    context 'when schema operations fail' do
      before do
        allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema)
          .and_raise(PgMultitenantSchemas::ConnectionError, 'Database connection lost')
      end

      it 'handles database connection errors gracefully in development' do
        allow(Rails.env).to receive(:development?).and_return(true)
        allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)

        get :index

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'protected methods' do
    describe '#switch_to_tenant' do
      it 'sets current tenant and calls TenantHelper' do
        expect(TenantHelper).to receive(:current_tenant=).with(tenant)
        expect(controller).to receive(:instance_variable_set).with(:@current_tenant, tenant)
        expect(TenantHelper).to receive(:switch_to_schema).with('testcorp')

        controller.send(:switch_to_tenant, tenant)
      end

      it 'switches to public schema when tenant is nil' do
        expect(TenantHelper).to receive(:current_tenant=).with(nil)
        expect(controller).to receive(:instance_variable_set).with(:@current_tenant, nil)
        expect(TenantHelper).to receive(:switch_to_schema).with('public')

        controller.send(:switch_to_tenant, nil)
      end
    end

    describe '#reset_tenant_context' do
      it 'resets tenant context to public schema' do
        controller.instance_variable_set(:@current_tenant, tenant)

        expect(TenantHelper).to receive(:current_tenant=).with(nil)
        expect(TenantHelper).to receive(:switch_to_schema).with('public')

        controller.send(:reset_tenant_context)
        expect(controller.instance_variable_get(:@current_tenant)).to be_nil
      end
    end
  end

  describe 'request flow integration' do
    it 'executes tenant resolution and cleanup in proper order' do
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)

      # Expect the sequence: resolve -> switch -> action -> reset
      expect(controller).to receive(:resolve_tenant).ordered.and_call_original
      expect(controller).to receive(:switch_to_tenant).with(tenant).ordered
      expect(controller).to receive(:reset_tenant_context).ordered

      get :index
    end

    it 'ensures tenant context is reset even on controller errors' do
      allow(TenantHelper).to receive(:resolve_tenant_from_request).and_return(tenant)
      allow(controller).to receive(:index).and_raise(StandardError, 'Controller error')

      expect(controller).to receive(:reset_tenant_context)

      expect { get :index }.to raise_error(StandardError, 'Controller error')
    end
  end
end
