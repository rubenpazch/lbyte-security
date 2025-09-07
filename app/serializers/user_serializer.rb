class UserSerializer
  def initialize(user)
    @user = user
  end

  def serializable_hash
    {
      data: {
        attributes: {
          id: @user.id,
          email: @user.email,
          username: @user.username,
          status: @user.status,
          language: @user.language,
          first_name: @user.first_name,
          last_name: @user.last_name,
          roles: @user.roles.pluck(:name),
          created_at: @user.created_at,
          updated_at: @user.updated_at
        }
      }
    }
  end
end
