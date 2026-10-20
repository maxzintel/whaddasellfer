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

ActiveRecord::Schema[8.1].define(version: 2026_10_20_190200) do
  create_table "games", force: :cascade do |t|
    t.integer "puzzle_id", null: false
    t.string "token", null: false
    t.string "player_name", null: false
    t.integer "score", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["puzzle_id", "completed_at", "score"], name: "index_games_on_puzzle_id_and_completed_at_and_score"
    t.index ["puzzle_id"], name: "index_games_on_puzzle_id"
    t.index ["token"], name: "index_games_on_token", unique: true
  end

  create_table "listings", force: :cascade do |t|
    t.string "source_id", null: false
    t.integer "year", null: false
    t.string "make", null: false
    t.string "model", null: false
    t.string "title", null: false
    t.integer "mileage"
    t.string "transmission"
    t.string "body_style"
    t.string "exterior_color"
    t.string "interior_color"
    t.string "title_status"
    t.text "highlights"
    t.json "image_urls", default: [], null: false
    t.integer "sold_price", null: false
    t.datetime "sold_at", null: false
    t.string "source", null: false
    t.string "source_url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id"], name: "index_listings_on_source_id", unique: true
  end

  create_table "puzzle_listings", force: :cascade do |t|
    t.integer "puzzle_id", null: false
    t.integer "listing_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["listing_id"], name: "index_puzzle_listings_on_listing_id"
    t.index ["puzzle_id", "listing_id"], name: "index_puzzle_listings_on_puzzle_id_and_listing_id", unique: true
    t.index ["puzzle_id", "position"], name: "index_puzzle_listings_on_puzzle_id_and_position", unique: true
    t.index ["puzzle_id"], name: "index_puzzle_listings_on_puzzle_id"
  end

  create_table "puzzles", force: :cascade do |t|
    t.date "puzzle_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["puzzle_date"], name: "index_puzzles_on_puzzle_date", unique: true
  end

  create_table "rounds", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "listing_id", null: false
    t.integer "position", null: false
    t.integer "guess"
    t.integer "points"
    t.datetime "guessed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "listing_id"], name: "index_rounds_on_game_id_and_listing_id", unique: true
    t.index ["game_id", "position"], name: "index_rounds_on_game_id_and_position", unique: true
    t.index ["game_id"], name: "index_rounds_on_game_id"
    t.index ["listing_id"], name: "index_rounds_on_listing_id"
  end

  add_foreign_key "games", "puzzles"
  add_foreign_key "puzzle_listings", "listings"
  add_foreign_key "puzzle_listings", "puzzles"
  add_foreign_key "rounds", "games"
  add_foreign_key "rounds", "listings"
end
