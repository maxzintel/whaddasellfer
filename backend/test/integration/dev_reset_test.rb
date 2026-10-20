require "test_helper"

class DevResetTest < ActionDispatch::IntegrationTest
  TODAY = Time.zone.local(2026, 10, 20, 12)

  setup { travel_to TODAY }

  test "reset_today deletes today's puzzle, games and rounds, and the next game starts fresh" do
    finished = Game.start!(player_name: "Done")
    finished.rounds.each { |round| round.guess!(10_000) }
    Game.start!(player_name: "Halfway")
    yesterday = Game.start!(player_name: "Yesterday", date: TODAY.to_date - 1)

    post "/api/dev/reset_today"

    assert_response :success
    assert_equal({ "puzzle_date" => "2026-10-20", "games_deleted" => 2 }, response.parsed_body)
    assert_nil Puzzle.find_by(puzzle_date: TODAY.to_date)
    assert_equal [ yesterday.id ], Game.pluck(:id)
    assert_equal 5, Round.count, "only yesterday's rounds remain"

    get "/api/leaderboard"
    assert_empty response.parsed_body["entries"]

    post "/api/games", params: { player_name: "Fresh" }, as: :json
    assert_response :created
    assert_equal 5, response.parsed_body["rounds"].size
  end

  test "reset_today with no puzzle today is a no-op" do
    post "/api/dev/reset_today"

    assert_response :success
    assert_equal 0, response.parsed_body["games_deleted"]
  end

  test "the endpoint and the model refuse outside development and test" do
    Game.start!(player_name: "Keep me")
    production = ActiveSupport::EnvironmentInquirer.new("production")

    with_singleton_stub(Rails, :env, ->(_original) { production }) do
      post "/api/dev/reset_today"
      assert_response :not_found

      assert_raises(RuntimeError) { Puzzle.reset_day!(TODAY.to_date) }
      assert_raises(RuntimeError) { Puzzle.reset_all! }
    end
    assert_equal 1, Game.count
  end

  test "reset_all deletes every puzzle and game but keeps listings" do
    Game.start!(player_name: "Today")
    Game.start!(player_name: "Yesterday", date: TODAY.to_date - 1)

    assert_equal 2, Puzzle.reset_all!
    assert_equal [ 0, 0, 0, 0 ], [ Puzzle.count, PuzzleListing.count, Game.count, Round.count ]
    assert_equal 7, Listing.count
  end
end
