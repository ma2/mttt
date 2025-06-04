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

ActiveRecord::Schema[8.0].define(version: 2025_06_01_112016) do
  create_table "boards", force: :cascade do |t|
    t.integer "game_id", null: false
    t.string "name", null: false
    t.string "winner"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_boards_on_game_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "mode", default: "local", null: false
    t.string "current_player", default: "X", null: false
    t.string "next_board"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "moves", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "board_id", null: false
    t.integer "panel_id", null: false
    t.string "player", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["board_id"], name: "index_moves_on_board_id"
    t.index ["game_id"], name: "index_moves_on_game_id"
    t.index ["panel_id"], name: "index_moves_on_panel_id"
  end

  create_table "panels", force: :cascade do |t|
    t.integer "board_id", null: false
    t.integer "index", null: false
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["board_id"], name: "index_panels_on_board_id"
  end

  add_foreign_key "boards", "games"
  add_foreign_key "moves", "boards"
  add_foreign_key "moves", "games"
  add_foreign_key "moves", "panels"
  add_foreign_key "panels", "boards"
end
