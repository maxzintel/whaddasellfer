class CreateGamesAndRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :puzzle, null: false, foreign_key: true
      t.string :token, null: false
      t.string :player_name, null: false
      t.integer :score, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end
    add_index :games, :token, unique: true
    add_index :games, [ :puzzle_id, :completed_at, :score ]

    create_table :rounds do |t|
      t.references :game, null: false, foreign_key: true
      t.references :listing, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :guess
      t.integer :points
      t.datetime :guessed_at
      t.timestamps
    end
    add_index :rounds, [ :game_id, :position ], unique: true
    add_index :rounds, [ :game_id, :listing_id ], unique: true
  end
end
