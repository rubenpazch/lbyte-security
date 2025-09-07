# frozen_string_literal: true

class Tenant < ApplicationRecord
  # Validations
  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: { case_sensitive: false }
  validates :status, inclusion: { in: %w[active inactive trial suspended] }
  validates :plan, inclusion: { in: %w[basic professional enterprise] }, allow_nil: true
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Subdomain format validation
  validates :subdomain, format: {
    with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/,
    message: "can only contain lowercase letters, numbers, and hyphens (not at the beginning or end)"
  }

  # Prevent reserved subdomains
  validates :subdomain, exclusion: {
    in: %w[public information_schema pg_catalog www api admin mail ftp blog support help docs],
    message: "is reserved and cannot be used"
  }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :trial, -> { where(status: "trial") }
  scope :inactive, -> { where(status: "inactive") }

  # Callbacks
  before_validation :normalize_subdomain
  after_create :create_apartment_schema
  before_destroy :drop_apartment_schema

  # Instance methods
  def active?
    status == "active"
  end

  def trial?
    status == "trial"
  end

  def inactive?
    status == "inactive"
  end

  def suspended?
    status == "suspended"
  end

  def full_domain(base_domain = "localhost:3000")
    "#{subdomain}.#{base_domain}"
  end

  def trial_expired?
    trial? && trial_ends_at.present? && trial_ends_at < Time.current
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain&.downcase&.strip
  end

  def create_apartment_schema
    return unless subdomain.present?

    begin
      TenantHelper.create_tenant_schema(self)
      Rails.logger.info "Created schema '#{subdomain}' for tenant #{id}"
    rescue => e
      Rails.logger.info "Schema '#{subdomain}' may already exist: #{e.message}"
    end
  end

  def drop_apartment_schema
    return unless subdomain.present?

    begin
      TenantHelper.drop_tenant_schema(self)
      Rails.logger.info "Dropped schema '#{subdomain}' for tenant #{id}"
    rescue => e
      Rails.logger.info "Schema '#{subdomain}' may not exist: #{e.message}"
    end
  end
end
