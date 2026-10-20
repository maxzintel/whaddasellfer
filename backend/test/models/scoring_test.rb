require "test_helper"

class ScoringTest < ActiveSupport::TestCase
  test "exact guess scores 1000" do
    assert_equal 1000, Scoring.points(guess: 25_000, actual: 25_000)
  end

  test "10% off either way scores 800" do
    assert_equal 800, Scoring.points(guess: 27_500, actual: 25_000)
    assert_equal 800, Scoring.points(guess: 22_500, actual: 25_000)
  end

  test "50% off or worse scores 0" do
    assert_equal 0, Scoring.points(guess: 37_500, actual: 25_000)
    assert_equal 0, Scoring.points(guess: 12_500, actual: 25_000)
    assert_equal 0, Scoring.points(guess: 1_000_000, actual: 25_000)
    assert_equal 0, Scoring.points(guess: 1, actual: 25_000)
  end

  test "rounds half away from zero with exact math" do
    # 1000 * (1 - 2 * 1/2000) = 999 exactly; 1000 * (1 - 2 * 1/4000) = 999.5 -> 1000
    assert_equal 999, Scoring.points(guess: 2001, actual: 2000)
    assert_equal 1000, Scoring.points(guess: 4001, actual: 4000)
    # 1000 * (1 - 2 * 1/3) = 333.33.. -> 333
    assert_equal 333, Scoring.points(guess: 2, actual: 3)
  end

  test "rejects non-positive or non-integer inputs" do
    assert_raises(ArgumentError) { Scoring.points(guess: 0, actual: 25_000) }
    assert_raises(ArgumentError) { Scoring.points(guess: -5, actual: 25_000) }
    assert_raises(ArgumentError) { Scoring.points(guess: 25_000, actual: 0) }
    assert_raises(ArgumentError) { Scoring.points(guess: 2.5, actual: 25_000) }
  end
end
