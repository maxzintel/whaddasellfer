class Round < ApplicationRecord
  belongs_to :game
  belongs_to :listing

  validates :position, inclusion: { in: 1..Puzzle::ROUNDS }, uniqueness: { scope: :game_id }
  validates :listing_id, uniqueness: { scope: :game_id }
  validates :guess, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  def guessed?
    !guess.nil?
  end
end
