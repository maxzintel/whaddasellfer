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
end
