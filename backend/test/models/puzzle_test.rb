require "test_helper"

class PuzzleTest < ActiveSupport::TestCase
  DAY = Date.new(2026, 10, 20)

  test "creates the day's puzzle with 5 distinct listings in positions 1-5" do
    puzzle = Puzzle.for_date!(DAY)

    assert_equal DAY, puzzle.puzzle_date
    assert_equal [ 1, 2, 3, 4, 5 ], puzzle.puzzle_listings.map(&:position)
    assert_equal 5, puzzle.listings.distinct.count
  end

  test "returns the same puzzle for the same date" do
    first = Puzzle.for_date!(DAY)

    assert_no_difference -> { Puzzle.count } do
      assert_equal first, Puzzle.for_date!(DAY)
    end
  end

  test "the next day prefers listings no earlier puzzle used" do
    day_one_ids = Puzzle.for_date!(DAY).listings.ids
    unused_ids = Listing.ids - day_one_ids
    assert_equal 2, unused_ids.size

    day_two_ids = Puzzle.for_date!(DAY + 1).listings.ids

    assert_equal 5, day_two_ids.uniq.size
    assert_empty unused_ids - day_two_ids, "day 2 should use both unused listings"
  end

  test "falls back to already-used listings once every listing has run" do
    Puzzle.for_date!(DAY)
    Puzzle.for_date!(DAY + 1)

    day_three = Puzzle.for_date!(DAY + 2)

    assert_equal 5, day_three.listings.distinct.count
  end

  test "fails loudly when there aren't enough listings" do
    Listing.where.not(id: Listing.limit(4).ids).delete_all

    error = assert_raises(RuntimeError) { Puzzle.for_date!(DAY) }
    assert_match "Need at least 5 listings", error.message
  end

  test "race: losing the uniqueness validation returns the winner's puzzle" do
    winner = Puzzle.for_date!(DAY)

    assert_no_difference [ "Puzzle.count", "PuzzleListing.count" ] do
      with_find_by_missing_once do
        assert_equal winner, Puzzle.for_date!(DAY)
      end
    end
  end

  test "race: hitting the unique index returns the winner's puzzle" do
    winner = Puzzle.for_date!(DAY)
    # Skip validation, as if the winner committed between our validation and our INSERT.
    insert_without_validation = ->(_original, **attrs) { Puzzle.new(**attrs).tap { |p| p.save!(validate: false) } }

    assert_no_difference [ "Puzzle.count", "PuzzleListing.count" ] do
      with_find_by_missing_once do
        with_singleton_stub(Puzzle, :create!, insert_without_validation) do
          assert_equal winner, Puzzle.for_date!(DAY)
        end
      end
    end
  end

  private

  # The first lookup misses, as if another request created the puzzle right after it.
  def with_find_by_missing_once(&)
    calls = 0
    lookup = ->(original, *args, **kwargs) { (calls += 1) == 1 ? nil : original.call(*args, **kwargs) }
    with_singleton_stub(Puzzle, :find_by, lookup, &)
    assert_operator calls, :>=, 2, "expected the rescue to re-read the puzzle"
  end
end
