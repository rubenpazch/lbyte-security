class Permission < ApplicationRecord
  self.primary_key = "id"

  # Associations
  has_and_belongs_to_many :roles, join_table: :role_permissions

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :resource, presence: true
  validates :action, presence: true
  validates :resource, :action, uniqueness: { scope: [ :resource, :action ] }

  # Scopes
  scope :system_permissions, -> { where(is_system: true) }
  scope :custom_permissions, -> { where(is_system: false) }
  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :for_action, ->(action) { where(action: action) }

  # Callbacks
  before_validation :generate_id, on: :create
  before_validation :normalize_resource_and_action

  # Class methods
  def self.create_permission(name:, description:, resource:, action:, is_system: true)
    create(
      name: name,
      description: description,
      resource: resource,
      action: action,
      is_system: is_system
    )
  end

  # Instance methods
  def system_permission?
    is_system
  end

  def custom_permission?
    !is_system
  end

  def full_name
    "#{resource}:#{action}"
  end

  def to_s
    name
  end

  private

  def generate_id
    return if id.present?

    last_permission = Permission.order(:created_at).last
    if last_permission&.id&.match(/perm-(\d+)/)
      next_number = $1.to_i + 1
      self.id = "perm-#{next_number.to_s.rjust(3, '0')}"
    else
      self.id = "perm-001"
    end
  end

  def normalize_resource_and_action
    self.resource = resource&.downcase&.pluralize
    self.action = action&.downcase
  end
end
