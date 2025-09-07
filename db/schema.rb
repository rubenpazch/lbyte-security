# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_02_015539) do
  create_schema "acme"
  create_schema "alpha"
  create_schema "basic"
  create_schema "beta"
  create_schema "demo"
  create_schema "freshstartup"
  create_schema "gamma"
  create_schema "newcompany"
  create_schema "test"
  create_schema "testcorp"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "jwt_denylists", force: :cascade do |t|
    t.string "jti"
    t.datetime "exp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "permissions", id: :string, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "resource", null: false
    t.string "action", null: false
    t.boolean "is_system", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_system"], name: "index_permissions_on_is_system"
    t.index ["name"], name: "index_permissions_on_name", unique: true
    t.index ["resource", "action"], name: "index_permissions_on_resource_and_action", unique: true
  end

  create_table "role_permissions", force: :cascade do |t|
    t.string "role_id", null: false
    t.string "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", id: :string, force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "color"
    t.string "icon"
    t.boolean "is_system", default: false
    t.boolean "is_active", default: true
    t.integer "level"
    t.json "permission_ids", default: []
    t.integer "user_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_roles_on_is_active"
    t.index ["is_system"], name: "index_roles_on_is_system"
    t.index ["level"], name: "index_roles_on_level"
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "status", default: "active", null: false
    t.string "plan", default: "basic"
    t.text "description"
    t.string "contact_email"
    t.string "contact_name"
    t.datetime "trial_ends_at"
    t.jsonb "settings", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metadata"], name: "index_tenants_on_metadata", using: :gin
    t.index ["plan"], name: "index_tenants_on_plan"
    t.index ["settings"], name: "index_tenants_on_settings", using: :gin
    t.index ["status"], name: "index_tenants_on_status"
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
    t.index ["trial_ends_at"], name: "index_tenants_on_trial_ends_at"
  end

  create_table "user_roles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone"
    t.string "occupation"
    t.string "company_name"
    t.string "location"
    t.string "flag"
    t.string "activity"
    t.string "status", default: "active"
    t.string "pic"
    t.string "avatar"
    t.string "user_name"
    t.string "user_gmail"
    t.string "full_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["full_name"], name: "index_users_on_full_name"
    t.index ["location"], name: "index_users_on_location"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["status"], name: "index_users_on_status"
    t.index ["user_name"], name: "index_users_on_user_name"
  end

  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
end
