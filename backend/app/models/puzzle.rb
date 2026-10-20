# The day's 5 cars, shared by every game started that day (Eastern time).
class Puzzle < ApplicationRecord
  ROUNDS = 5

  has_many :puzzle_listings, -> { order(:position) }, dependent: :destroy
  has_many :listings, through: :puzzle_listings
  has_many :games, dependent: :restrict_with_exception

  validates :puzzle_date, presence: true, uniqueness: true
end
