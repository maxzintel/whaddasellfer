class CreatePuzzles < ActiveRecord::Migration[8.1]
  def change
    create_table :puzzles do |t|
      t.date :puzzle_date, null: false
      t.timestamps
    end
    add_index :puzzles, :puzzle_date, unique: true

    create_table :puzzle_listings do |t|
      t.references :puzzle, null: false, foreign_key: true
      t.references :listing, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
    end
    add_index :puzzle_listings, [ :puzzle_id, :position ], unique: true
    add_index :puzzle_listings, [ :puzzle_id, :listing_id ], unique: true
  end
end
