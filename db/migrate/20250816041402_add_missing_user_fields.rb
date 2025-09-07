class AddMissingUserFields < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :phone, :string
    add_column :users, :occupation, :string
    add_column :users, :company_name, :string
    add_column :users, :location, :string
    add_column :users, :flag, :string
    add_column :users, :activity, :string
    add_column :users, :status, :string, default: 'active'
    add_column :users, :pic, :string
    add_column :users, :avatar, :string
    add_column :users, :user_name, :string
    add_column :users, :user_gmail, :string
    add_column :users, :full_name, :string

    # Add indexes for commonly searched fields
    add_index :users, :status
    add_index :users, :location
    add_index :users, :full_name
    add_index :users, :user_name
  end
end
