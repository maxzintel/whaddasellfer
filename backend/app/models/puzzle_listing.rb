class PuzzleListing < ApplicationRecord
  belongs_to :puzzle
  belongs_to :listing

  validates :position, inclusion: { in: 1..Puzzle::ROUNDS }, uniqueness: { scope: :puzzle_id }
  validates :listing_id, uniqueness: { scope: :puzzle_id }
end
