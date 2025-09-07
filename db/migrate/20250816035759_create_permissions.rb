class CreatePermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :permissions, id: false do |t|
      t.string :id, primary_key: true
      t.string :name, null: false
      t.text :description
      t.string :resource, null: false
      t.string :action, null: false
      t.boolean :is_system, default: true

      t.timestamps
    end

    add_index :permissions, :name, unique: true
    add_index :permissions, [ :resource, :action ], unique: true
    add_index :permissions, :is_system
  end
end
