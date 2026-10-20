class Game < ApplicationRecord
  has_secure_token :token

  belongs_to :puzzle
  has_many :rounds, -> { order(:position) }, dependent: :destroy

  normalizes :player_name, with: ->(name) { name.squish }

  validates :player_name, presence: true, length: { maximum: 30 }
  validates :score, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :completed, -> { where.not(completed_at: nil) }

  # Starts a game on the puzzle for `date`: one round per puzzle listing, same order.
  # The puzzle is fetched first, outside this transaction, so a puzzle-creation race is
  # resolved (and rescued) before the game's own transaction opens.
  def self.start!(player_name:, date: Time.zone.today)
    puzzle = Puzzle.for_date!(date)

    transaction do
      game = create!(puzzle:, player_name:)
      puzzle.puzzle_listings.each do |puzzle_listing|
        game.rounds.create!(listing_id: puzzle_listing.listing_id, position: puzzle_listing.position)
      end
      game
    end
  end

  # Completed games for one puzzle, best first. Ties go to whoever finished first.
  def self.leaderboard(puzzle, limit: 10)
    where(puzzle:).completed.order(score: :desc, completed_at: :asc, id: :asc).limit(limit)
  end

  def completed?
    completed_at.present?
  end

  # `position` comes straight from the URL: anything but an integer 1..5 is a 404.
  def round_at!(position)
    rounds.find_by!(position: Integer(position.to_s, 10, exception: false))
  end

  # Recomputed from the rounds, never incremented, so running it twice is harmless.
  # Queries the table directly so a stale, already-loaded `rounds` can't skew it.
  def refresh_score!
    self.score = Round.where(game_id: id).sum(:points)
    self.completed_at ||= Time.current unless Round.where(game_id: id, guess: nil).exists?
    save!
  end
end
