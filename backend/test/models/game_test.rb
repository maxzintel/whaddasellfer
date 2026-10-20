require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup { @puzzle = Puzzle.create!(puzzle_date: Date.new(2026, 10, 20)) }

  test "gets a random 24-char token on create" do
    game = Game.create!(puzzle: @puzzle, player_name: "Max")

    assert_equal 24, game.token.length
    refute_equal game.token, Game.create!(puzzle: @puzzle, player_name: "Max").token
  end

  test "squishes and validates player_name" do
    assert_equal "Max Z", Game.new(player_name: "  Max   Z ").player_name
    refute Game.new(puzzle: @puzzle, player_name: "   ").valid?
    refute Game.new(puzzle: @puzzle, player_name: "x" * 31).valid?
  end

  test "start! copies the day's puzzle into 5 rounds in order" do
    game = Game.start!(player_name: "Max", date: Date.new(2026, 10, 21))
    puzzle = Puzzle.find_by!(puzzle_date: Date.new(2026, 10, 21))

    assert_equal puzzle, game.puzzle
    assert_equal puzzle.puzzle_listings.map { |pl| [ pl.position, pl.listing_id ] },
      game.rounds.map { |round| [ round.position, round.listing_id ] }
    assert game.rounds.none?(&:guessed?)
    assert_equal 0, game.score
  end

  test "start! defaults to today in Eastern time" do
    travel_to Time.utc(2026, 10, 21, 3, 30) do # 23:30 on the 20th in New York
      assert_equal Date.new(2026, 10, 20), Game.start!(player_name: "Max").puzzle.puzzle_date
    end
  end

  test "start! raises RecordInvalid for a bad name and creates no game" do
    assert_no_difference [ "Game.count", "Round.count" ] do
      assert_raises(ActiveRecord::RecordInvalid) { Game.start!(player_name: " ", date: Date.new(2026, 10, 21)) }
      assert_raises(ActiveRecord::RecordInvalid) { Game.start!(player_name: "x" * 31, date: Date.new(2026, 10, 21)) }
    end
  end

  test "refresh_score! sums round points and is safe to repeat" do
    game = Game.start!(player_name: "Max", date: Date.new(2026, 10, 21))
    game.rounds.to_a # load the association so a stale cache would show up
    Round.where(game: game, position: [ 1, 2 ]).update_all(guess: 1, points: 300)

    2.times { game.refresh_score! }

    assert_equal 600, game.reload.score
    assert_nil game.completed_at
  end

  test "refresh_score! sets completed_at once all rounds are guessed and never moves it" do
    game = Game.start!(player_name: "Max", date: Date.new(2026, 10, 21))
    Round.where(game: game).update_all(guess: 1, points: 100)

    finished = Time.zone.local(2026, 10, 21, 12)
    travel_to(finished) { game.refresh_score! }
    travel_to(finished + 1.hour) { game.refresh_score! }

    assert_equal 500, game.reload.score
    assert_equal finished, game.completed_at
  end

  test "leaderboard: completed games for the puzzle, score desc then earliest finish" do
    other_day = Puzzle.create!(puzzle_date: Date.new(2026, 10, 21))
    noon = Time.zone.local(2026, 10, 20, 12)
    late_tie = Game.create!(puzzle: @puzzle, player_name: "Late tie", score: 3000, completed_at: noon + 2.minutes)
    best = Game.create!(puzzle: @puzzle, player_name: "Best", score: 4000, completed_at: noon + 5.minutes)
    early_tie = Game.create!(puzzle: @puzzle, player_name: "Early tie", score: 3000, completed_at: noon)
    Game.create!(puzzle: @puzzle, player_name: "Unfinished", score: 4500)
    Game.create!(puzzle: other_day, player_name: "Other day", score: 5000, completed_at: noon)

    assert_equal [ best, early_tie, late_tie ], Game.leaderboard(@puzzle).to_a
    assert_equal [ best ], Game.leaderboard(@puzzle, limit: 1).to_a
  end
end
