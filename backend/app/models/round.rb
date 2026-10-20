class Round < ApplicationRecord
  class AlreadyGuessed < StandardError; end
  class InvalidGuess < StandardError; end

  MAX_GUESS = 100_000_000

  belongs_to :game
  belongs_to :listing

  validates :position, inclusion: { in: 1..Puzzle::ROUNDS }, uniqueness: { scope: :game_id }
  validates :listing_id, uniqueness: { scope: :game_id }
  validates :guess, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Turns a guess from JSON (an integer, or a string of digits) into whole dollars.
  # Anything else raises InvalidGuess with a message fit to show the player.
  def self.coerce_guess(raw)
    amount =
      case raw
      when Integer then raw
      when /\A-?\d+\z/ then raw.to_i
      when nil, "" then raise InvalidGuess, "Guess is required"
      else raise InvalidGuess, "Guess must be a whole number of dollars, like 25000"
      end

    raise InvalidGuess, "Guess must be more than $0" unless amount.positive?
    raise InvalidGuess, "Guess must be $100,000,000 or less" if amount > MAX_GUESS

    amount
  end

  def guessed?
    !guess.nil?
  end

  # Scores the guess and updates the game's total. The row lock (plus SQLite's
  # BEGIN IMMEDIATE) serializes concurrent guesses, so only the first one counts.
  def guess!(raw_guess)
    amount = self.class.coerce_guess(raw_guess)

    with_lock do
      raise AlreadyGuessed, "Round #{position} has already been guessed" if guessed?

      points = Scoring.points(guess: amount, actual: listing.sold_price)
      update!(guess: amount, points:, guessed_at: Time.current)
      game.refresh_score!
    end
  end
end
