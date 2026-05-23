class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets do |t|
      t.string :slug, null: false
      t.string :display_name, null: false
      t.string :display_meta
      t.float :mu, null: false
      t.float :sigma, null: false

      t.timestamps
    end
    add_index :assets, :slug, unique: true
  end
end
