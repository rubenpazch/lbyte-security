class CreateUserRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true, type: :bigint
      t.references :role, null: false, foreign_key: { to_table: :roles }, type: :string

      t.timestamps
    end

    add_index :user_roles, [ :user_id, :role_id ], unique: true
  end
end
