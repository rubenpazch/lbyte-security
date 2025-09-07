class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles, id: false do |t|
      t.string :id, primary_key: true
      t.string :name, null: false
      t.text :description
      t.string :color
      t.string :icon
      t.boolean :is_system, default: false
      t.boolean :is_active, default: true
      t.integer :level
      t.json :permission_ids, default: []
      t.integer :user_count, default: 0

      t.timestamps
    end

    add_index :roles, :name, unique: true
    add_index :roles, :is_system
    add_index :roles, :is_active
    add_index :roles, :level
  end
end
