# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110422111836) do

  create_table "channels", :force => true do |t|
    t.string   "protocol"
    t.string   "address"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
    t.string   "activation_code"
    t.text     "data"
  end

  add_index "channels", ["protocol", "address"], :name => "index_channels_on_protocol_and_address"
  add_index "channels", ["user_id", "status"], :name => "index_channels_on_user_id_and_status"

  create_table "groups", :force => true do |t|
    t.string   "alias"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "requires_approval_to_join", :default => false
    t.boolean  "chatroom",                  :default => true
    t.boolean  "enabled",                   :default => true
    t.boolean  "forward_owners",            :default => false
    t.string   "alias_downcase"
    t.text     "data"
    t.text     "description"
    t.boolean  "hidden",                    :default => true
  end

  add_index "groups", ["alias_downcase"], :name => "index_groups_on_alias_downcase"

  create_table "invites", :force => true do |t|
    t.integer  "group_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "user_accepted",  :default => false
    t.boolean  "admin_accepted", :default => false
    t.integer  "requestor_id"
  end

  add_index "invites", ["group_id", "user_id"], :name => "index_invites_on_group_id_and_user_id"

  create_table "memberships", :force => true do |t|
    t.integer  "group_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "role"
  end

  add_index "memberships", ["group_id", "user_id"], :name => "index_memberships_on_group_id_and_user_id"
  add_index "memberships", ["group_id"], :name => "index_memberships_on_group_id"

  create_table "messages", :force => true do |t|
    t.integer  "sender_id"
    t.integer  "group_id"
    t.string   "text"
    t.decimal  "lat",                :precision => 10, :scale => 6
    t.decimal  "lon",                :precision => 10, :scale => 6
    t.string   "location"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "location_short_url"
    t.text     "data"
  end

  add_index "messages", ["group_id", "created_at"], :name => "index_messages_on_group_id_and_created_at"
  add_index "messages", ["sender_id"], :name => "index_messages_on_sender_id"

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "display_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "password"
    t.integer  "default_group_id"
    t.boolean  "created_from_invite",                                 :default => false
    t.decimal  "lat",                  :precision => 10, :scale => 6
    t.decimal  "lon",                  :precision => 10, :scale => 6
    t.string   "location"
    t.datetime "location_reported_at"
    t.string   "login_downcase"
    t.string   "location_short_url"
    t.text     "data"
  end

  add_index "users", ["login_downcase", "created_from_invite"], :name => "index_users_on_login_downcase_and_created_from_invite"

end
