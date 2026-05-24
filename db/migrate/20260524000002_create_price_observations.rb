class CreatePriceObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :price_observations do |t|
      t.references :asset, null: false, foreign_key: true
      t.date :observed_on, null: false
      t.float :close, null: false

      t.timestamps
    end
    add_index :price_observations, [ :asset_id, :observed_on ], unique: true
  end
end
