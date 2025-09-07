class Api::UsersController < ApplicationController
  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :set_user, only: [ :show, :update, :destroy, :toggle_status, :assign_role, :remove_role ]
  before_action :ensure_admin_or_self, only: [ :update, :destroy ]
  before_action :ensure_admin, only: [ :create, :toggle_status, :assign_role, :remove_role ]

  # GET /api/users
  def index
    @users = User.includes(:roles).all

    # Apply filters if provided
    @users = @users.where(status: params[:status]) if params[:status].present?
    @users = @users.where(language: params[:language]) if params[:language].present?
    @users = @users.with_role(params[:role]) if params[:role].present?

    # Apply search if provided
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @users = @users.where(
        "email ILIKE ? OR user_name ILIKE ? OR occupation ILIKE ? OR company_name ILIKE ?",  # Fixed: use existing columns
        search_term, search_term, search_term, search_term
      )
    end

    # Apply pagination
    page = params[:page]&.to_i || 1
    per_page = [ params[:per_page]&.to_i || 20, 100 ].min # Max 100 per page
    offset = (page - 1) * per_page

    @users = @users.limit(per_page).offset(offset)
    total_count = User.count

    # Set pagination variables for Jbuilder
    @current_page = page
    @per_page = per_page
    @total_count = total_count
    @total_pages = (total_count.to_f / per_page).ceil

    render "index", formats: [ :json ]
  end

  # GET /api/users/:id
  def show
    render "show", formats: [ :json ]
  end

  # POST /api/users (Admin only - different from registration)
  def create
    @user = User.new(user_params)

    if @user.save
      # Assign roles if provided
      assign_roles(@user, params[:user][:role_names]) if params[:user][:role_names].present?

      render "create", status: :created, formats: [ :json ]
    else
      render json: {
        status: { message: "User couldn't be created. #{@user.errors.full_messages.to_sentence}" },
        errors: @user.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # PATCH/PUT /api/users/:id
  def update
    if @user.update(user_update_params)
      # Update roles if provided and user is admin
      if params[:user][:role_names].present? && (current_user.admin? || current_user.super_admin?)
        assign_roles(@user, params[:user][:role_names])
      end

      render "update", formats: [ :json ]
    else
      render json: {
        status: { message: "User couldn't be updated. #{@user.errors.full_messages.to_sentence}" },
        errors: @user.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # DELETE /api/users/:id
  def destroy
    # Prevent users from deleting themselves
    if @user == current_user
      return render json: {
        status: { message: "You cannot delete your own account through this endpoint." }
      }, status: :forbidden
    end

    # Prevent deleting super admins unless you are one
    if @user.super_admin? && !current_user.super_admin?
      return render json: {
        status: { message: "Only super admins can delete other super admin accounts." }
      }, status: :forbidden
    end

    if @user.destroy
      render "destroy", formats: [ :json ]
    else
      render json: {
        status: { message: "User couldn't be deleted. #{@user.errors.full_messages.to_sentence}" },
        errors: @user.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # POST /api/users/:id/toggle_status
  def toggle_status
    set_user
    ensure_admin_or_self

    new_status = @user.status == "active" ? "inactive" : "active"

    if @user.update(status: new_status)
      render "toggle_status", formats: [ :json ]
    else
      render json: {
        status: { message: "Status couldn't be updated. #{@user.errors.full_messages.to_sentence}" },
        errors: @user.errors.full_messages
      }, status: :unprocessable_content
    end
  end

  # POST /api/users/:id/assign_role
  def assign_role
    set_user
    ensure_admin

    role_name = params[:role_name]

    if role_name.blank?
      return render json: {
        status: { message: "Role name is required." }
      }, status: :bad_request
    end

    role = Role.find_by(name: role_name)

    if role.nil?
      return render json: {
        status: { message: "Role '#{role_name}' not found." }
      }, status: :not_found
    end

    if @user.add_role(role_name)
      render "assign_role", formats: [ :json ]
    else
      render json: {
        status: { message: "Role couldn't be assigned." }
      }, status: :unprocessable_content
    end
  end

  # DELETE /api/users/:id/remove_role
  def remove_role
    set_user
    ensure_admin

    role_name = params[:role_name]

    if role_name.blank?
      return render json: {
        status: { message: "Role name is required." }
      }, status: :bad_request
    end

    if @user.remove_role(role_name)
      render "remove_role", formats: [ :json ]
    else
      render json: {
        status: { message: "Role couldn't be removed or user doesn't have this role." }
      }, status: :unprocessable_content
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      status: { message: "User not found." }
    }, status: :not_found
  end

  def user_params
    params.require(:user).permit(
      :email, :password, :password_confirmation, :user_name, :status,  # Fixed: removed language, changed username to user_name
      :phone, :occupation, :company_name, :location, :flag, :activity, :pic, :avatar, :user_gmail  # Fixed: use existing columns
    )
  end

  def user_update_params
    # Don't allow password changes through this endpoint
    # Allow admin users to update status; regular users cannot toggle this.
    permitted = [
      :email, :user_name, :status,  # Fixed: use user_name, removed language
      :phone, :occupation, :company_name, :location, :flag, :activity, :pic, :avatar, :user_gmail  # Fixed: use existing columns
    ]
    # Note: is_active column doesn't exist, using status instead

    params.require(:user).permit(*permitted)
  end

  def ensure_admin
    unless current_user&.admin?
      render json: {
        status: { message: "Access denied. Admin privileges required." }
      }, status: :forbidden
    end
  end

  def ensure_admin_or_self
    unless current_user&.admin? || @user&.id == current_user&.id
      render json: {
        status: { message: "Access denied. You can only manage your own account." }
      }, status: :forbidden
    end
  end

  def assign_roles(user, role_names)
    return unless role_names.is_a?(Array)

    # Clear existing roles (except for super admins)
    unless user.super_admin?
      user.roles.clear
    end

    # Add new roles
    role_names.each do |role_name|
      user.add_role(role_name)
    end
  end
end
