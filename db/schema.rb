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

ActiveRecord::Schema[8.1].define(version: 2026_05_24_000003) do
  create_table "assets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "data_source", default: 1, null: false
    t.string "display_meta"
    t.string "display_name", null: false
    t.float "mu", null: false
    t.float "sigma", null: false
    t.string "slug", null: false
    t.string "symbol"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_assets_on_slug", unique: true
    t.index ["symbol"], name: "index_assets_on_symbol", unique: true
  end

  create_table "comparisons", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.date "data_as_of", null: false
    t.string "dedup_key", null: false
    t.integer "horizon_years", null: false
    t.float "mu_a_snapshot", null: false
    t.float "mu_b_snapshot", null: false
    t.json "results_json", null: false
    t.integer "scenario_id", null: false
    t.integer "seed", limit: 8, null: false
    t.float "sigma_a_snapshot", null: false
    t.float "sigma_b_snapshot", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["dedup_key"], name: "index_comparisons_on_dedup_key", unique: true
    t.index ["scenario_id"], name: "index_comparisons_on_scenario_id"
    t.index ["slug"], name: "index_comparisons_on_slug", unique: true
  end

  create_table "market_data_fetches", force: :cascade do |t|
    t.integer "asset_id", null: false
    t.datetime "created_at", null: false
    t.string "detail"
    t.integer "observations_count"
    t.integer "status", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_market_data_fetches_on_asset_id"
  end

  create_table "price_observations", force: :cascade do |t|
    t.integer "asset_id", null: false
    t.float "close", null: false
    t.datetime "created_at", null: false
    t.date "observed_on", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id", "observed_on"], name: "index_price_observations_on_asset_id_and_observed_on", unique: true
    t.index ["asset_id"], name: "index_price_observations_on_asset_id"
  end

  create_table "scenario_paths", force: :cascade do |t|
    t.integer "asset_id", null: false
    t.integer "behavior", default: 0, null: false
    t.json "behavior_params", default: {}, null: false
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.string "meta"
    t.integer "role", null: false
    t.integer "scenario_id", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_scenario_paths_on_asset_id"
    t.index ["scenario_id", "role"], name: "index_scenario_paths_on_scenario_id_and_role", unique: true
    t.index ["scenario_id"], name: "index_scenario_paths_on_scenario_id"
  end

  create_table "scenarios", force: :cascade do |t|
    t.string "chip_icon"
    t.string "chip_meta"
    t.boolean "coupled_randomness", default: false, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "€", null: false
    t.integer "default_amount", null: false
    t.integer "default_horizon_years", null: false
    t.string "headline_key", null: false
    t.string "insight_key"
    t.string "setup_title"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_scenarios_on_slug", unique: true
  end

  add_foreign_key "comparisons", "scenarios"
  add_foreign_key "market_data_fetches", "assets"
  add_foreign_key "price_observations", "assets"
  add_foreign_key "scenario_paths", "assets"
  add_foreign_key "scenario_paths", "scenarios"
end
