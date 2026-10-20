require "test_helper"

class RoundTest < ActiveSupport::TestCase
  setup do
    @game = Game.start!(player_name: "Max", date: Date.new(2026, 10, 20))
    @round = @game.rounds.first
  end

  test "coerce_guess accepts positive whole dollars as integers or digit strings" do
    assert_equal 25_000, Round.coerce_guess(25_000)
    assert_equal 25_000, Round.coerce_guess("25000")
    assert_equal 1, Round.coerce_guess(1)
    assert_equal 100_000_000, Round.coerce_guess(100_000_000)
    assert_equal 100_000_000, Round.coerce_guess("100000000")
  end

  test "coerce_guess rejects anything else with a helpful message" do
    {
      nil => "Guess is required",
      "" => "Guess is required",
      0 => "Guess must be more than $0",
      "0" => "Guess must be more than $0",
      -5 => "Guess must be more than $0",
      "-5" => "Guess must be more than $0",
      1.5 => "Guess must be a whole number of dollars, like 25000",
      25_000.0 => "Guess must be a whole number of dollars, like 25000",
      "1.5" => "Guess must be a whole number of dollars, like 25000",
      "25,000" => "Guess must be a whole number of dollars, like 25000",
      "$25000" => "Guess must be a whole number of dollars, like 25000",
      " 25000" => "Guess must be a whole number of dollars, like 25000",
      "abc" => "Guess must be a whole number of dollars, like 25000",
      true => "Guess must be a whole number of dollars, like 25000",
      [ 25_000 ] => "Guess must be a whole number of dollars, like 25000",
      100_000_001 => "Guess must be $100,000,000 or less",
      "9" * 40 => "Guess must be $100,000,000 or less"
    }.each do |raw, message|
      error = assert_raises(Round::InvalidGuess, "expected #{raw.inspect} to be rejected") { Round.coerce_guess(raw) }
      assert_equal message, error.message, "message for #{raw.inspect}"
    end
  end

  test "guess! scores the round and updates the game" do
    actual = @round.listing.sold_price

    @round.guess!((actual * 11 / 10).to_s)

    @round.reload
    assert_equal actual * 11 / 10, @round.guess
    assert_equal 800, @round.points
    assert_not_nil @round.guessed_at
    assert_equal 800, @game.reload.score
    assert_nil @game.completed_at
  end

  test "guess! refuses a second guess and keeps the first" do
    @round.guess!(@round.listing.sold_price)

    assert_raises(Round::AlreadyGuessed) { @round.guess!(1) }
    assert_raises(Round::AlreadyGuessed) { Round.find(@round.id).guess!(1) }
    assert_equal 1000, @round.reload.points
    assert_equal 1000, @game.reload.score
  end

  test "guess! validates before touching the round" do
    assert_raises(Round::InvalidGuess) { @round.guess!("abc") }

    assert_not @round.reload.guessed?
  end
end
