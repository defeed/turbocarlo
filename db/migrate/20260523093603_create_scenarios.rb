class CreateScenarios < ActiveRecord::Migration[8.1]
  def change
    create_table :scenarios do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.string :chip_meta
      t.string :chip_icon
      t.string :setup_title
      t.string :currency, null: false, default: "€"
      t.integer :default_amount, null: false
      t.integer :default_horizon_years, null: false
      t.string :headline_key, null: false
      t.string :insight_key
      t.boolean :coupled_randomness, null: false, default: false

      t.timestamps
    end
    add_index :scenarios, :slug, unique: true
  end
end
