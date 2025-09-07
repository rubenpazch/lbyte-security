# frozen_string_literal: true

class CreateTenants < ActiveRecord::Migration[8.0]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :status, null: false, default: 'active'
      t.string :plan, default: 'basic'
      t.text :description
      t.string :contact_email
      t.string :contact_name
      t.datetime :trial_ends_at
      t.jsonb :settings, default: {}
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Add indices
    add_index :tenants, :subdomain, unique: true
    add_index :tenants, :status
    add_index :tenants, :plan
    add_index :tenants, :trial_ends_at
    add_index :tenants, :settings, using: :gin
    add_index :tenants, :metadata, using: :gin
  end
end
