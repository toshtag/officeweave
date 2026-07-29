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

ActiveRecord::Schema[8.1].define(version: 2026_07_29_073437) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "announcement_departments", force: :cascade do |t|
    t.bigint "announcement_id", null: false
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.datetime "updated_at", null: false
    t.index ["announcement_id", "department_id"], name: "index_announcement_departments_on_pair", unique: true
    t.index ["announcement_id"], name: "index_announcement_departments_on_announcement_id"
    t.index ["department_id"], name: "index_announcement_departments_on_department_id"
  end

  create_table "announcement_reads", force: :cascade do |t|
    t.bigint "announcement_id", null: false
    t.datetime "created_at", null: false
    t.datetime "read_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["announcement_id", "user_id"], name: "index_announcement_reads_on_pair", unique: true
    t.index ["announcement_id"], name: "index_announcement_reads_on_announcement_id"
    t.index ["user_id"], name: "index_announcement_reads_on_user_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.datetime "published_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "organization", null: false
    t.index ["author_id"], name: "index_announcements_on_author_id"
    t.index ["organization_id", "published_at"], name: "index_announcements_on_organization_id_and_published_at"
    t.index ["organization_id"], name: "index_announcements_on_organization_id"
  end

  create_table "departments", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "parent_id"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "code"], name: "index_departments_on_organization_id_and_code", unique: true
    t.index ["organization_id"], name: "index_departments_on_organization_id"
    t.index ["parent_id"], name: "index_departments_on_parent_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id", null: false
    t.boolean "primary", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["department_id"], name: "index_memberships_on_department_id"
    t.index ["user_id", "department_id"], name: "index_memberships_on_user_id_and_department_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_primary_user", unique: true, where: "\"primary\""
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_organizations_on_code", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deactivated_at"
    t.string "email_address", null: false
    t.string "locale"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "password_digest", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.index ["deactivated_at"], name: "index_users_on_deactivated_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "announcement_departments", "announcements"
  add_foreign_key "announcement_departments", "departments"
  add_foreign_key "announcement_reads", "announcements"
  add_foreign_key "announcement_reads", "users"
  add_foreign_key "announcements", "organizations"
  add_foreign_key "announcements", "users", column: "author_id"
  add_foreign_key "departments", "departments", column: "parent_id"
  add_foreign_key "departments", "organizations"
  add_foreign_key "memberships", "departments"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "organizations"
end
