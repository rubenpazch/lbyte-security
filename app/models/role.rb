class Role < ApplicationRecord
  self.primary_key = "id"

  # Associations
  has_and_belongs_to_many :users, join_table: :user_roles
  has_and_belongs_to_many :permissions, join_table: :role_permissions

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :level, presence: true, uniqueness: true
  validates :color, presence: true, format: { with: /\A#[0-9a-fA-F]{6}\z/ }
  validates :icon, presence: true

  # Scopes
  scope :system_roles, -> { where(is_system: true) }
  scope :custom_roles, -> { where(is_system: false) }
  scope :active, -> { where(is_active: true) }
  scope :by_level, -> { order(:level) }

  # Callbacks
  before_validation :generate_id, on: :create
  before_save :update_user_count

  # Instance methods
  def system_role?
    is_system
  end

  def custom_role?
    !is_system
  end

  def has_permission?(permission_identifier)
    # Support both permission objects, IDs, and names
    case permission_identifier
    when Permission
      permissions.exists?(id: permission_identifier.id)
    when String
      if permission_identifier.start_with?("perm-")
        permissions.exists?(id: permission_identifier) || permission_ids.include?(permission_identifier)
      else
        permissions.exists?(name: permission_identifier)
      end
    else
      false
    end
  end

  def add_permission(permission_identifier)
    permission = find_permission(permission_identifier)
    return false unless permission

    unless has_permission?(permission_identifier)
      permissions << permission
      # Also add to permission_ids for backward compatibility
      self.permission_ids = (permission_ids + [ permission.id ]).uniq
      save
    end
  end

  def remove_permission(permission_identifier)
    permission = find_permission(permission_identifier)
    return false unless permission

    if has_permission?(permission_identifier)
      permissions.delete(permission)
      # Also remove from permission_ids for backward compatibility
      self.permission_ids = permission_ids - [ permission.id ]
      save
    end
  end

  def permission_names
    permissions.pluck(:name)
  end

  def permission_list
    permissions.pluck(:id)
  end

  private

  def find_permission(permission_identifier)
    case permission_identifier
    when Permission
      permission_identifier
    when String
      if permission_identifier.start_with?("perm-")
        Permission.find_by(id: permission_identifier)
      else
        Permission.find_by(name: permission_identifier)
      end
    else
      nil
    end
  end

  def generate_id
    return if id.present?

    last_role = Role.order(:created_at).last
    if last_role&.id&.match(/role-(\d+)/)
      next_number = $1.to_i + 1
      self.id = "role-#{next_number.to_s.rjust(3, '0')}"
    else
      self.id = "role-001"
    end
  end

  def update_user_count
    self.user_count = users.count if persisted?
  end
end
