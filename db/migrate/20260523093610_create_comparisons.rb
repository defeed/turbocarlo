class CreateComparisons < ActiveRecord::Migration[8.1]
  def change
    create_table :comparisons do |t|
      t.references :scenario, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :dedup_key, null: false
      t.integer :amount, null: false
      t.integer :horizon_years, null: false
      t.integer :seed, null: false, limit: 8
      t.float :mu_a_snapshot, null: false
      t.float :sigma_a_snapshot, null: false
      t.float :mu_b_snapshot, null: false
      t.float :sigma_b_snapshot, null: false
      t.date :data_as_of, null: false
      t.json :results_json, null: false

      t.timestamps
    end
    add_index :comparisons, :slug, unique: true
    add_index :comparisons, :dedup_key, unique: true
  end
end
