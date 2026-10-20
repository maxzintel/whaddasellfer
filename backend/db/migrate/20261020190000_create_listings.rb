class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.string :source_id, null: false
      t.integer :year, null: false
      t.string :make, null: false
      t.string :model, null: false
      t.string :title, null: false
      t.integer :mileage
      t.string :transmission
      t.string :body_style
      t.string :exterior_color
      t.string :interior_color
      t.string :title_status
      t.text :highlights
      t.json :image_urls, null: false, default: []
      t.integer :sold_price, null: false
      t.datetime :sold_at, null: false
      t.string :source, null: false
      t.string :source_url, null: false
      t.timestamps
    end
    add_index :listings, :source_id, unique: true
  end
end
