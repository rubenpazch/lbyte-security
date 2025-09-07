class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Associations
  has_and_belongs_to_many :roles, join_table: :user_roles

  # Validations
  validates :user_name, uniqueness: true, allow_blank: true  # Fixed: was 'username', now 'user_name'
  validates :email, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active inactive pending suspended] }
  # Note: language column doesn't exist in current schema, removing validation

  # Scopes
  scope :active, -> { where(status: 'active') }  # Fixed: use 'status' instead of 'is_active'
  scope :admins, -> { joins(:roles).where(roles: { name: ['Admin', 'Super Admin'] }) }  # Fixed: use roles instead of 'is_admin'
  # Note: email_verified column doesn't exist, using role-based verification
  scope :verified, -> { where.not(status: 'pending') }  # Fixed: use status instead of 'email_verified'
  scope :with_role, ->(role_name) { joins(:roles).where(roles: { name: role_name }) }

  # Callbacks
  before_create :set_defaults
  after_create :assign_default_role

  # Instance methods
  def fullname
    # Since first_name and last_name columns don't exist, use user_name or email
    user_name.present? ? user_name : email.split("@").first
  end

  def admin?
    has_role?("Admin") || has_role?("Super Admin")  # Fixed: removed 'is_admin' reference
  end

  def super_admin?
    has_role?("Super Admin")
  end

  def active?
    status == "active"  # Fixed: removed 'is_active' reference
  end

  def has_role?(role_name)
    roles.exists?(name: role_name)
  end

  def add_role(role_name)
    role = Role.find_by(name: role_name)
    return false unless role

    roles << role unless has_role?(role_name)
  end

  def remove_role(role_name)
    role = Role.find_by(name: role_name)
    return false unless role

    roles.delete(role)
  end

  def primary_role
    roles.order(:level).first
  end

  def role
    primary_role&.name || "User"
  end

  # Permission checking methods
  def has_permission?(permission_identifier)
    return true if super_admin? # Super admins have all permissions

    roles.any? { |role| role.has_permission?(permission_identifier) }
  end

  def can?(action, resource)
    permission_name = "#{action.to_s.capitalize} #{resource.to_s.capitalize.pluralize}"
    has_permission?(permission_name) || has_permission?("#{resource.to_s.downcase.pluralize}:#{action}")
  end

  def permissions
    Permission.joins(:roles).where(roles: { id: role_ids }).distinct
  end

  def permission_names
    permissions.pluck(:name)
  end

  def all_permissions
    roles.includes(:permissions).flat_map(&:permissions).uniq
  end

  def user_profile
    {
      avatar: avatar || pic,
      userName: user_name || fullname,  # Fixed: removed 'username' reference
      userGmail: user_gmail || email,
      fullname: fullname,
      # Note: first_name and last_name columns don't exist in current schema
      username: user_name,  # Fixed: use 'user_name' instead of 'username'
      email: email,
      phone: phone,
      occupation: occupation,
      company_name: company_name,
      pic: pic,
      location: location,
      flag: flag,
      activity: activity,
      full_name: full_name || fullname,
      account_access: account_access || []
    }
  end

  def user
    {
      avatar: avatar || pic || "default-avatar.png",
      userName: display_name,
      userGmail: user_gmail || email
    }
  end

  # Additional helper methods for the new fields
  def display_name
    user_name.present? ? user_name : fullname
  end

  def status_info
    {
      label: status&.capitalize || "Active",
      color: status_color
    }
  end

  def add_account_access(account_id, role, permissions = [])
    current_access = account_access || []
    existing_access = current_access.find { |access| access["account_id"] == account_id }

    if existing_access
      existing_access["role"] = role
      existing_access["permissions"] = permissions
    else
      current_access << {
        "account_id" => account_id,
        "role" => role,
        "permissions" => permissions
      }
    end

    update(account_access: current_access)
  end

  def remove_account_access(account_id)
    current_access = account_access || []
    current_access.reject! { |access| access["account_id"] == account_id }
    update(account_access: current_access)
  end

  def has_account_access?(account_id)
    return false unless account_access
    account_access.any? { |access| access["account_id"] == account_id }
  end

  def roles_array
    roles.pluck(:id)
  end

  def update_last_activity!
    update_columns(
      last_activity_at: Time.current,
      activity: "Last seen #{Time.current.strftime('%B %d, %Y at %I:%M %p')}"
    )
  end

  def update_last_login!
    update_columns(
      last_login_at: Time.current,
      last_activity_at: Time.current
    )
  end

  private

  def status_color
    case status&.downcase
    when "active" then "success"
    when "inactive" then "secondary"
    when "pending" then "warning"
    when "suspended" then "danger"
    when "remote" then "primary"
    else "secondary"
    end
  end

  def set_defaults
    self.status ||= "active"
    # Note: language, is_active, is_admin, email_verified columns don't exist in current schema
    # Default behavior is handled through status and roles
  end

  def assign_default_role
    default_role = Role.find_by(name: "User") || Role.find_by(level: 5)
    add_role(default_role.name) if default_role
  end
end
