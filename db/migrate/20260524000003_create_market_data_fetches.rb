class CreateMarketDataFetches < ActiveRecord::Migration[8.1]
  def change
    create_table :market_data_fetches do |t|
      t.references :asset, null: false, foreign_key: true
      t.integer :status, null: false
      t.integer :observations_count
      t.string :detail

      t.timestamps
    end
  end
end
