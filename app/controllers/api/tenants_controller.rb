# frozen_string_literal: true

class Api::TenantsController < ApplicationController
  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :ensure_super_admin, only: [ :create, :update, :destroy ]
  before_action :switch_to_public_schema  # Tenant operations happen in public schema
  before_action :set_tenant, only: [ :show, :update, :destroy ]

  # GET /api/tenants
  def index
    @tenants = Tenant.active.order(:name)
    render json: {
      status: { code: 200, message: "Tenants retrieved successfully" },
      data: @tenants.as_json(only: [ :id, :name, :subdomain, :status, :plan, :created_at ])
    }
  end

  # GET /api/tenants/:id
  def show
    render json: {
      status: { code: 200, message: "Tenant retrieved successfully" },
      data: @tenant.as_json(except: [ :settings ])
    }
  end

  # POST /api/tenants
  def create
    @tenant = Tenant.new(tenant_params)

    if @tenant.save
      # Schema creation is handled by model callback (after_create :create_apartment_schema)

      # Run migrations in new schema (in real implementation)
      TenantHelper.with_tenant(@tenant) do
        # ActiveRecord::MigrationContext.new(Rails.root.join('db', 'migrate')).migrate
        Rails.logger.info "Migrations would run here for tenant: #{@tenant.subdomain}"
      end

      render json: {
        status: { code: 201, message: "Tenant created successfully" },
        data: @tenant.as_json(except: [ :settings ])
      }, status: :created
    else
      render json: {
        status: { message: "Tenant creation failed: #{@tenant.errors.full_messages.to_sentence}" },
        errors: @tenant.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # PUT /api/tenants/:id
  def update
    if @tenant.update(tenant_params)
      render json: {
        status: { code: 200, message: "Tenant updated successfully" },
        data: @tenant.as_json(except: [ :settings ])
      }
    else
      render json: {
        status: { message: "Tenant update failed: #{@tenant.errors.full_messages.to_sentence}" },
        errors: @tenant.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # DELETE /api/tenants/:id
  def destroy
    if @tenant.destroy
      # Schema deletion is handled by model callback (before_destroy :drop_apartment_schema)

      render json: {
        status: { code: 200, message: "Tenant deleted successfully" }
      }
    else
      render json: {
        status: { message: "Tenant deletion failed: #{@tenant.errors.full_messages.to_sentence}" },
        errors: @tenant.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  private

  def set_tenant
    @tenant = Tenant.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: { message: "Tenant not found" }
    }, status: :not_found
  end

  def tenant_params
    params.require(:tenant).permit(:name, :subdomain, :status, :plan, :description, :contact_email, :contact_name, :trial_ends_at)
  end

  def ensure_super_admin
    unless current_user&.super_admin?
      render json: {
        status: { message: "Access denied. Super admin privileges required." }
      }, status: :forbidden
    end
  end

  def switch_to_public_schema
    # Tenant management operations must happen in public schema where tenants table exists
    TenantHelper.switch_to_schema("public")
  rescue PgMultitenantSchemas::ConnectionError => e
    # Handle schema switching errors gracefully in development
    if Rails.env.development?
      Rails.logger.warn "Schema switching failed in development: #{e.message}"
    else
      raise e
    end
  end
end
