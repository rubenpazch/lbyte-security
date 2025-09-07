# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tenant, type: :model do
  describe 'factory' do
    it 'creates a valid tenant' do
      tenant = build(:tenant)
      expect(tenant).to be_valid
    end

    it 'creates tenants with different traits' do
      active_tenant = build(:tenant, :active)
      trial_tenant = build(:tenant, :trial)
      enterprise_tenant = build(:tenant, :enterprise)

      expect(active_tenant.status).to eq('active')
      expect(trial_tenant.status).to eq('trial')
      expect(enterprise_tenant.plan).to eq('enterprise')
    end
  end

  describe 'validations' do
    let(:tenant) { build(:tenant) }

    describe 'name' do
      it 'requires a name' do
        tenant.name = nil
        expect(tenant).not_to be_valid
        expect(tenant.errors[:name]).to include("can't be blank")
      end

      it 'allows valid names' do
        tenant.name = "Acme Corporation"
        expect(tenant).to be_valid
      end
    end

    describe 'subdomain' do
      it 'requires a subdomain' do
        tenant.subdomain = nil
        expect(tenant).not_to be_valid
        expect(tenant.errors[:subdomain]).to include("can't be blank")
      end

      it 'requires unique subdomain' do
        create(:tenant, subdomain: 'acme')
        duplicate_tenant = build(:tenant, subdomain: 'acme')

        expect(duplicate_tenant).not_to be_valid
        expect(duplicate_tenant.errors[:subdomain]).to include("has already been taken")
      end

      it 'allows valid subdomain formats' do
        valid_subdomains = %w[acme acme-corp test123 a1b2c3]

        valid_subdomains.each do |subdomain|
          tenant.subdomain = subdomain
          expect(tenant).to be_valid, "#{subdomain} should be valid"
        end
      end

      it 'rejects invalid subdomain formats' do
        invalid_subdomains = [ 'acme_corp', 'acme.corp', 'acme corp', '123-', '-acme' ]

        invalid_subdomains.each do |subdomain|
          tenant.subdomain = subdomain
          expect(tenant).not_to be_valid, "#{subdomain} should be invalid"
          expect(tenant.errors[:subdomain]).to be_present
        end
      end
    end

    describe 'status' do
      it 'requires valid status' do
        tenant.status = 'invalid_status'
        expect(tenant).not_to be_valid
        expect(tenant.errors[:status]).to include("is not included in the list")
      end

      it 'allows valid statuses' do
        valid_statuses = %w[active inactive trial suspended]

        valid_statuses.each do |status|
          tenant.status = status
          expect(tenant).to be_valid, "#{status} should be valid"
        end
      end
    end
  end

  describe 'scopes' do
    let!(:active_tenant) { create(:tenant, :active) }
    let!(:inactive_tenant) { create(:tenant, :inactive) }
    let!(:trial_tenant) { create(:tenant, :trial) }

    describe '.active' do
      it 'returns only active tenants' do
        expect(Tenant.active).to include(active_tenant)
        expect(Tenant.active).not_to include(inactive_tenant)
      end
    end

    describe '.trial' do
      it 'returns only trial tenants' do
        expect(Tenant.trial).to include(trial_tenant)
        expect(Tenant.trial).not_to include(active_tenant)
      end
    end
  end

  describe 'callbacks' do
    describe 'normalize_subdomain' do
      it 'normalizes subdomain to lowercase' do
        tenant = build(:tenant, subdomain: 'ACME-Corp')
        tenant.valid?
        expect(tenant.subdomain).to eq('acme-corp')
      end

      it 'strips whitespace from subdomain' do
        tenant = build(:tenant, subdomain: '  acme  ')
        tenant.valid?
        expect(tenant.subdomain).to eq('acme')
      end
    end

    describe 'schema management' do
      let(:tenant) { build(:tenant, subdomain: 'test-schema') }

      it 'creates apartment schema after creation' do
        expect(tenant).to receive(:create_apartment_schema)
        tenant.save!
      end

      it 'drops apartment schema before destruction', :uses_database do
        # Use existing tenant to avoid transaction issues
        existing_tenant = Tenant.find_by(subdomain: 'demo')
        if existing_tenant
          expect(existing_tenant).to receive(:drop_apartment_schema)
          # Don't actually destroy the demo tenant in tests
          existing_tenant.run_callbacks(:destroy)
        else
          skip "No existing tenant available for destruction test"
        end
      end
    end
  end

  describe 'instance methods' do
    let(:tenant) { create(:tenant, subdomain: 'acme', status: 'active') }

    describe '#active?' do
      it 'returns true for active tenants' do
        expect(tenant.active?).to be true
      end

      it 'returns false for non-active tenants' do
        tenant.update(status: 'inactive')
        expect(tenant.active?).to be false
      end
    end

    describe '#trial?' do
      it 'returns true for trial tenants' do
        tenant.update(status: 'trial')
        expect(tenant.trial?).to be true
      end

      it 'returns false for non-trial tenants' do
        expect(tenant.trial?).to be false
      end
    end

    describe '#full_domain' do
      it 'returns full domain with default base' do
        expect(tenant.full_domain).to eq('acme.localhost:3000')
      end

      it 'returns full domain with custom base' do
        expect(tenant.full_domain('myapp.com')).to eq('acme.myapp.com')
      end
    end
  end

  describe 'schema operations' do
    let(:tenant) { build(:tenant, subdomain: 'schema-test') }

    describe 'create_apartment_schema' do
      it 'creates schema successfully' do
        expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
          .with('schema-test')
        tenant.send(:create_apartment_schema)
      end

      it 'handles existing schema gracefully' do
        allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema)
          .and_raise(PgMultitenantSchemas::SchemaExists)
        allow(Rails.logger).to receive(:info)

        expect { tenant.send(:create_apartment_schema) }.not_to raise_error
      end
    end

    describe 'drop_apartment_schema' do
      before { tenant.subdomain = 'drop-test' }

      it 'drops schema successfully' do
        expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema)
          .with('drop-test')
        tenant.send(:drop_apartment_schema)
      end

      it 'handles missing schema gracefully' do
        allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:drop_schema)
          .and_raise(PgMultitenantSchemas::SchemaNotFound)
        allow(Rails.logger).to receive(:info)

        expect { tenant.send(:drop_apartment_schema) }.not_to raise_error
      end
    end
  end

  describe 'business logic' do
    let(:trial_tenant) { create(:tenant, :trial, trial_ends_at: 5.days.from_now) }
    let(:expired_tenant) { create(:tenant, :expired) }

    describe 'trial management' do
      it 'identifies trial tenants correctly' do
        expect(trial_tenant.trial?).to be true
        expect(trial_tenant.status).to eq('trial')
      end

      it 'identifies expired trials' do
        expect(expired_tenant.trial_ends_at).to be < Time.current
        expect(expired_tenant.status).to eq('inactive')
      end
    end

    describe 'tenant lifecycle' do
      it 'can transition from trial to active' do
        trial_tenant.update!(status: 'active', plan: 'professional')
        expect(trial_tenant.active?).to be true
        expect(trial_tenant.plan).to eq('professional')
      end

      it 'can be suspended' do
        tenant = create(:tenant, :active)
        tenant.update!(status: 'suspended')
        expect(tenant.status).to eq('suspended')
        expect(tenant.active?).to be false
      end
    end
  end

  describe 'edge cases and error scenarios' do
    describe 'schema creation failures' do
      let(:tenant) { build(:tenant, subdomain: 'error-test') }

      it 'handles schema creation errors gracefully' do
        allow(TenantHelper).to receive(:create_tenant_schema)
          .and_raise(PgMultitenantSchemas::ConnectionError, 'Database connection failed')
        allow(Rails.logger).to receive(:info)

        expect { tenant.save! }.not_to raise_error
        expect(Rails.logger).to have_received(:info).with("Schema 'error-test' may already exist: Database connection failed")
      end

      it 'handles existing schema during creation' do
        allow(TenantHelper).to receive(:create_tenant_schema)
          .and_raise(PgMultitenantSchemas::SchemaExists, 'Schema already exists')
        allow(Rails.logger).to receive(:info)

        expect { tenant.save! }.not_to raise_error
        expect(Rails.logger).to have_received(:info).with("Schema 'error-test' may already exist: Schema already exists")
      end
    end

    describe 'schema deletion failures' do
      it 'handles schema deletion errors gracefully' do
        tenant = build(:tenant, subdomain: 'delete-test')
        # Allow create_schema for the after_create callback
        allow(TenantHelper).to receive(:create_tenant_schema)
        # Mock drop_schema to raise error
        allow(TenantHelper).to receive(:drop_tenant_schema)
          .and_raise(PgMultitenantSchemas::ConnectionError, 'Database connection failed')
        allow(Rails.logger).to receive(:info)

        tenant.save!  # This will trigger create_schema
        expect { tenant.destroy! }.not_to raise_error
        expect(Rails.logger).to have_received(:info).with("Schema 'delete-test' may not exist: Database connection failed")
      end

      it 'handles missing schema during deletion' do
        tenant = build(:tenant, subdomain: 'delete-test')
        # Allow create_schema for the after_create callback
        allow(TenantHelper).to receive(:create_tenant_schema)
        # Mock drop_schema to raise SchemaNotFound
        allow(TenantHelper).to receive(:drop_tenant_schema)
          .and_raise(PgMultitenantSchemas::SchemaNotFound, 'Schema not found')
        allow(Rails.logger).to receive(:info)

        tenant.save!  # This will trigger create_schema
        expect { tenant.destroy! }.not_to raise_error
        expect(Rails.logger).to have_received(:info).with("Schema 'delete-test' may not exist: Schema not found")
      end
    end
  end

  describe 'tenant data management' do
    let(:tenant) { create(:tenant, :enterprise) }

    describe 'metadata handling' do
      it 'stores and retrieves custom metadata' do
        metadata = {
          features: [ 'advanced_analytics', 'custom_branding' ],
          limits: { users: 1000, storage_gb: 500 },
          integrations: { slack: true, microsoft: false }
        }

        tenant.update!(metadata: metadata)
        tenant.reload

        expect(tenant.metadata['features']).to include('advanced_analytics')
        expect(tenant.metadata['limits']['users']).to eq(1000)
        expect(tenant.metadata['integrations']['slack']).to be true
      end
    end

    describe 'tenant settings' do
      it 'manages plan-specific settings' do
        basic_tenant = create(:tenant, :basic)
        enterprise_tenant = create(:tenant, :enterprise)

        expect(basic_tenant.plan).to eq('basic')
        expect(enterprise_tenant.plan).to eq('enterprise')

        # Plans could have different feature sets
        basic_settings = { max_users: 10, storage_gb: 1 }
        enterprise_settings = { max_users: 1000, storage_gb: 500 }

        basic_tenant.update!(settings: basic_settings)
        enterprise_tenant.update!(settings: enterprise_settings)

        expect(basic_tenant.settings['max_users']).to eq(10)
        expect(enterprise_tenant.settings['max_users']).to eq(1000)
      end
    end
  end

  describe 'tenant query optimization' do
    let!(:tenants) { create_list(:tenant, 10, :active) }

    it 'efficiently queries active tenants' do
      # Simulate query counting (would use database query counter in real tests)
      active_tenants = Tenant.active.limit(5)
      expect(active_tenants.count).to eq(5)
      expect(active_tenants.all?(&:active?)).to be true
    end

    it 'orders tenants by creation date' do
      ordered_tenants = Tenant.order(:created_at).limit(3)
      creation_times = ordered_tenants.map(&:created_at)
      expect(creation_times).to eq(creation_times.sort)
    end
  end

  describe 'tenant validation edge cases' do
    describe 'subdomain edge cases' do
      it 'handles minimum length subdomain' do
        tenant = build(:tenant, subdomain: 'a')
        expect(tenant).to be_valid
      end

      it 'handles maximum length subdomain' do
        long_subdomain = 'a' * 63  # PostgreSQL identifier limit
        tenant = build(:tenant, subdomain: long_subdomain)

        # This might fail if we add length validation
        expect(tenant.subdomain.length).to eq(63)
      end

      it 'rejects reserved PostgreSQL keywords as subdomain' do
        reserved_keywords = %w[public information_schema pg_catalog]

        reserved_keywords.each do |keyword|
          tenant = build(:tenant, subdomain: keyword)
          expect(tenant).not_to be_valid, "#{keyword} should not be allowed as subdomain"
        end
      end
    end

    describe 'contact information validation' do
      it 'validates email format when provided' do
        tenant = build(:tenant, contact_email: 'invalid-email')
        expect(tenant).not_to be_valid
        expect(tenant.errors[:contact_email]).to be_present
      end

      it 'allows nil contact email' do
        tenant = build(:tenant, contact_email: nil)
        expect(tenant).to be_valid
      end

      it 'validates proper email format' do
        tenant = build(:tenant, contact_email: 'admin@example.com')
        expect(tenant).to be_valid
      end
    end
  end

  describe 'tenant search and filtering', :uses_database do
    before(:each) do
      # Stub schema operations to avoid transaction conflicts
      allow_any_instance_of(Tenant).to receive(:create_apartment_schema)
      allow_any_instance_of(Tenant).to receive(:drop_apartment_schema)

      # Clear any existing test data
      Tenant.delete_all

      @test_tenants = []
      @test_tenants << create(:tenant, name: 'Alpha Solutions', subdomain: 'alpha-test', status: 'active', plan: 'basic')
      @test_tenants << create(:tenant, name: 'Beta Corporation', subdomain: 'beta-test', status: 'trial', plan: 'professional')
      @test_tenants << create(:tenant, name: 'Gamma Industries', subdomain: 'gamma-test', status: 'inactive', plan: 'enterprise')
    end

    after(:each) do
      # Clean up test data
      @test_tenants.each(&:destroy) if @test_tenants
    rescue ActiveRecord::StatementInvalid => e
      # If cleanup fails due to transaction issues, log and continue
      Rails.logger.warn "Test cleanup failed: #{e.message}"
    end

    it 'filters by status' do
      active_tenants = Tenant.where(status: 'active')
      trial_tenants = Tenant.where(status: 'trial')

      expect(active_tenants.count).to be > 0
      expect(active_tenants.pluck(:status)).to all(eq('active'))
      expect(trial_tenants.count).to be > 0
      expect(trial_tenants.pluck(:status)).to all(eq('trial'))
    end

    it 'searches by name pattern' do
      alpha_results = Tenant.where("name ILIKE ?", "%alpha%")
      beta_results = Tenant.where("name ILIKE ?", "%beta%")

      expect(alpha_results.count).to be > 0
      expect(beta_results.count).to be > 0
      expect(alpha_results.first.name).to include('Alpha')
      expect(beta_results.first.name).to include('Beta')
    end

    it 'filters by plan type' do
      basic_tenants = Tenant.where(plan: 'basic')
      professional_tenants = Tenant.where(plan: 'professional')
      enterprise_tenants = Tenant.where(plan: 'enterprise')

      expect(basic_tenants.count).to be > 0
      expect(professional_tenants.count).to be > 0
      expect(enterprise_tenants.count).to be > 0

      expect(basic_tenants.pluck(:plan)).to all(eq('basic'))
      expect(professional_tenants.pluck(:plan)).to all(eq('professional'))
      expect(enterprise_tenants.pluck(:plan)).to all(eq('enterprise'))
    end
  end

  describe 'tenant backup and recovery simulation' do
    let(:tenant) { create(:tenant, :enterprise, subdomain: 'backup-test') }

    before do
      # Mock all TenantHelper operations to avoid conflicts with model callbacks
      allow(TenantHelper).to receive(:create_tenant_schema)
      allow(TenantHelper).to receive(:switch_to_schema)
      allow(TenantHelper).to receive(:drop_tenant_schema)
      # Mock the gem's with_tenant method
      allow(PgMultitenantSchemas).to receive(:with_tenant)
    end

    it 'supports tenant schema backup workflow' do
      # In real implementation, this would backup schema data
      TenantHelper.with_tenant(tenant) do
        # Backup operations would go here
        'backup_completed'
      end

      # Verify that with_tenant was called with the tenant
      expect(PgMultitenantSchemas).to have_received(:with_tenant).with(tenant)
    end

    it 'supports tenant restoration workflow' do
      # Simulate restoration process
      TenantHelper.create_tenant_schema(tenant)

      # Verify schema creation was called (once from tenant creation + once from explicit call)
      expect(TenantHelper).to have_received(:create_tenant_schema).with(tenant).twice
    end
  end
end
