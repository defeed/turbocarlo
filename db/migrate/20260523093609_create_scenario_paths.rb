class CreateScenarioPaths < ActiveRecord::Migration[8.1]
  def change
    create_table :scenario_paths do |t|
      t.references :scenario, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.integer :role, null: false
      t.string :label, null: false
      t.string :meta
      t.integer :behavior, null: false, default: 0
      t.json :behavior_params, null: false, default: {}

      t.timestamps
    end
    add_index :scenario_paths, [ :scenario_id, :role ], unique: true
  end
end
