# The day's 5 cars, shared by every game started that day (Eastern time).
class Puzzle < ApplicationRecord
  ROUNDS = 5

  has_many :puzzle_listings, -> { order(:position) }, dependent: :destroy
  has_many :listings, through: :puzzle_listings
  has_many :games, dependent: :restrict_with_exception

  validates :puzzle_date, presence: true, uniqueness: true

  # Returns the puzzle for `date`, creating it on first request (docs/DESIGN.md §3).
  # The unique index on puzzle_date is the real guard against two first requests at once:
  # the loser's transaction rolls back and it re-reads the winner's row. The rescue sits
  # outside the transaction so the re-read never runs inside a failed one (Postgres-safe).
  def self.for_date!(date)
    find_by(puzzle_date: date) || create_with_listings!(date)
  rescue ActiveRecord::RecordNotUnique
    find_by!(puzzle_date: date)
  rescue ActiveRecord::RecordInvalid => e
    # If the winner committed before our uniqueness validation ran, we fail the
    # validation instead of hitting the index. Same race, same answer.
    raise unless e.record.is_a?(Puzzle) && e.record.errors.of_kind?(:puzzle_date, :taken)

    find_by!(puzzle_date: date)
  end

  def self.create_with_listings!(date)
    transaction do
      puzzle = create!(puzzle_date: date)
      pick_listings.each.with_index(1) do |listing, position|
        puzzle.puzzle_listings.create!(listing:, position:)
      end
      puzzle
    end
  end

  # Random listings no earlier puzzle has used. Once fewer than ROUNDS are left,
  # takes all of them and fills the rest at random from already-used listings.
  def self.pick_listings
    random = Arel.sql("RANDOM()")
    picked = Listing.where.not(id: PuzzleListing.select(:listing_id)).order(random).limit(ROUNDS).to_a
    if picked.size < ROUNDS
      picked += Listing.where.not(id: picked.map(&:id)).order(random).limit(ROUNDS - picked.size).to_a
    end
    raise "Need at least #{ROUNDS} listings to build a puzzle (run bin/rails db:seed)" if picked.size < ROUNDS

    picked.shuffle
  end
  private_class_method :create_with_listings!, :pick_listings
end
