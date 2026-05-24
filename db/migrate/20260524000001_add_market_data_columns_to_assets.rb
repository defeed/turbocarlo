class AddMarketDataColumnsToAssets < ActiveRecord::Migration[8.1]
  def change
    # data_source: 0 alpha_vantage, 1 manual, 2 derived. Existing rows are
    # fixed/seeded params, so they default to manual; seeds set the live ones.
    add_column :assets, :data_source, :integer, null: false, default: 1
    add_column :assets, :symbol, :string
    add_index :assets, :symbol, unique: true
  end
end
