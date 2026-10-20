require "test_helper"

class GameApiTest < ActionDispatch::IntegrationTest
  SECRET_KEYS = %w[sold_price source_url sold_at source_id].freeze
  TODAY = Time.zone.local(2026, 10, 20, 12)

  setup { travel_to TODAY }

  # --- Hard rule: never expose the price before the guess -------------------

  test "an unguessed game exposes no price or auction details anywhere" do
    game = start_game

    assert_response :created
    assert_empty all_keys(game) & SECRET_KEYS
    assert_equal 5, game["rounds"].size
    game["rounds"].each do |round|
      assert_nil round["result"]
      assert_equal Listing::PUBLIC_ATTRIBUTES.sort, round["listing"].keys.sort
      refute_includes response.body, Listing.find(round["listing"]["id"]).source_url
    end

    get "/api/games/#{game["token"]}"
    assert_empty all_keys(response.parsed_body) & SECRET_KEYS
  end

  test "after guessing round 1 only round 1 reveals the price" do
    token = start_game["token"]

    game = guess(token, 1, 12_345)

    assert_response :ok
    first, *rest = game["rounds"]
    listing = Listing.find(first["listing"]["id"])
    assert_equal %w[guess points pct_off sold_price sold_at source source_url].sort, first["result"].keys.sort
    assert_equal listing.sold_price, first["result"]["sold_price"]
    assert_equal listing.source_url, first["result"]["source_url"]
    assert_equal Listing::PUBLIC_ATTRIBUTES.sort, first["listing"].keys.sort
    rest.each do |round|
      assert_nil round["result"]
      assert_empty all_keys(round) & SECRET_KEYS, "round #{round["position"]} leaked"
    end
  end

  test "games and rounds carry no integer ids" do
    game = guess(start_game["token"], 1, 12_345)

    assert_equal %w[completed_at player_name puzzle_date rounds score token], game.keys.sort
    game["rounds"].each { |round| assert_equal %w[listing position result], round.keys.sort }
    refute_includes game["rounds"].first["result"].keys, "id"
  end

  test "the leaderboard never includes tokens" do
    token = play_full_game("Max")

    get "/api/leaderboard", params: { token: }

    assert_response :ok
    refute_includes all_keys(response.parsed_body), "token"
    refute_includes response.body, token
  end

  # --- Starting and reading games ---------------------------------------------

  test "creating a game returns the Game shape" do
    game = start_game("  Max   Z ")

    assert_equal 24, game["token"].length
    assert_equal "Max Z", game["player_name"]
    assert_equal "2026-10-20", game["puzzle_date"]
    assert_equal 0, game["score"]
    assert_nil game["completed_at"]
    assert_equal [ 1, 2, 3, 4, 5 ], game["rounds"].map { |round| round["position"] }
  end

  test "bad player names are 422" do
    [ "", "   ", "x" * 31, nil, [ "a" ], { "a" => 1 } ].each do |name|
      post "/api/games", params: { player_name: name }, as: :json

      assert_response :unprocessable_content, "name #{name.inspect}"
      assert_error_body
    end
    post "/api/games", params: {}, as: :json
    assert_response :unprocessable_content
    assert_equal "Player name can't be blank", response.parsed_body["error"]

    start_game("x" * 30)
    assert_response :created
  end

  test "unknown tokens are 404" do
    get "/api/games/nope"
    assert_response :not_found
    assert_equal({ "error" => "Game not found" }, response.parsed_body)

    post "/api/games/nope/rounds/1/guess", params: { guess: 1000 }, as: :json
    assert_response :not_found
    assert_error_body
  end

  test "positions outside 1-5 are 404" do
    token = start_game["token"]

    [ "0", "6", "abc", "1abc", "-1" ].each do |position|
      post "/api/games/#{token}/rounds/#{position}/guess", params: { guess: 1000 }, as: :json

      assert_response :not_found, "position #{position}"
      assert_error_body
    end
    get "/api/games/#{token}"
    assert_equal 0, response.parsed_body["score"]
  end

  test "two games on the same day get the same cars in the same order" do
    first = start_game("A")["rounds"].map { |round| round["listing"]["id"] }
    second = start_game("B")["rounds"].map { |round| round["listing"]["id"] }

    assert_equal first, second
    assert_equal 5, first.uniq.size
    assert_equal 1, Puzzle.count
  end

  test "the next day prefers cars nobody has seen" do
    day_one = start_game["rounds"].map { |round| round["listing"]["id"] }

    travel_to TODAY + 1.day
    game = start_game
    day_two = game["rounds"].map { |round| round["listing"]["id"] }

    assert_equal "2026-10-21", game["puzzle_date"]
    assert_equal 5, day_two.uniq.size
    assert_empty (Listing.ids - day_one) - day_two
  end

  # --- Guessing -----------------------------------------------------------------

  test "a guess returns the updated game with the scored result" do
    token = start_game["token"]
    actual = round_listing(token, 2).sold_price

    game = guess(token, 2, actual * 9 / 10)

    result = game["rounds"][1]["result"]
    assert_equal actual * 9 / 10, result["guess"]
    assert_equal 800, result["points"]
    assert_equal(-10.0, result["pct_off"])
    assert_equal "Bring a Trailer", result["source"]
    assert_equal round_listing(token, 2).sold_at, Time.iso8601(result["sold_at"])
    assert_equal 800, game["score"]
  end

  test "a guess may be a string of digits" do
    token = start_game["token"]

    guess(token, 1, "25000")

    assert_response :ok
    assert_equal 25_000, response.parsed_body["rounds"][0]["result"]["guess"]
  end

  test "pct_off is signed and rounded to one decimal" do
    token = start_game["token"]
    actual = round_listing(token, 1).sold_price

    game = guess(token, 1, actual + actual / 3)

    assert_equal 33.3, game["rounds"][0]["result"]["pct_off"]
  end

  test "a second guess on the same round is 422 and changes nothing" do
    token = start_game["token"]
    first = guess(token, 1, 12_345)

    guess(token, 1, round_listing(token, 1).sold_price)

    assert_response :unprocessable_content
    assert_equal "Round 1 has already been guessed", response.parsed_body["error"]
    get "/api/games/#{token}"
    assert_equal first["score"], response.parsed_body["score"]
    assert_equal first["rounds"][0]["result"], response.parsed_body["rounds"][0]["result"]
  end

  test "invalid guesses are 422 and leave the round unguessed" do
    token = start_game["token"]

    [ nil, "", 0, -5, 1.5, "1.5", "25,000", "abc", 100_000_001, { "amount" => 5 } ].each do |value|
      guess(token, 1, value)

      assert_response :unprocessable_content, "guess #{value.inspect}"
      assert_error_body
    end
    post "/api/games/#{token}/rounds/1/guess", params: {}, as: :json
    assert_response :unprocessable_content
    assert_equal "Guess is required", response.parsed_body["error"]

    get "/api/games/#{token}"
    assert_nil response.parsed_body["rounds"][0]["result"]
  end

  test "finishing all 5 rounds completes the game with the summed score" do
    token = start_game["token"]
    expected = 0
    game = nil

    [ 1, 3, 2, 5, 4 ].each_with_index do |position, i|
      actual = round_listing(token, position).sold_price
      amount = actual + actual * i / 10
      expected += Scoring.points(guess: amount, actual:)
      game = guess(token, position, amount)
      assert_nil game["completed_at"] unless i == 4
    end

    assert_equal expected, game["score"]
    assert_equal game["rounds"].sum { |round| round["result"]["points"] }, game["score"]
    assert_equal TODAY, Time.iso8601(game["completed_at"])
  end

  test "a game started before midnight can be finished after it and stays on its day's board" do
    travel_to Time.zone.local(2026, 10, 20, 23, 58)
    token = start_game["token"]

    travel_to Time.zone.local(2026, 10, 21, 0, 5)
    play_rounds(token)
    assert_response :ok
    game = response.parsed_body
    assert_equal "2026-10-20", game["puzzle_date"]
    assert_not_nil game["completed_at"]

    get "/api/leaderboard", params: { token: }
    assert_equal({ "puzzle_date" => "2026-10-21", "entries" => [] }, response.parsed_body)
    assert_nil Puzzle.find_by(puzzle_date: Date.new(2026, 10, 21)), "a GET must not create a puzzle"
    assert_equal [ token ], Game.leaderboard(Puzzle.find_by!(puzzle_date: Date.new(2026, 10, 20))).map(&:token)

    travel_to Time.zone.local(2026, 10, 20, 23, 59)
    get "/api/leaderboard", params: { token: }
    assert_equal [ true ], response.parsed_body["entries"].map { |entry| entry["you"] }
  end

  # --- Leaderboard --------------------------------------------------------------

  test "the leaderboard is empty, and creates nothing, before anyone plays today" do
    assert_no_difference -> { Puzzle.count } do
      get "/api/leaderboard"
    end

    assert_response :ok
    assert_equal({ "puzzle_date" => "2026-10-20", "entries" => [] }, response.parsed_body)
  end

  test "the leaderboard ranks today's completed games and flags yours" do
    puzzle = Puzzle.for_date!(Date.new(2026, 10, 20))
    late_tie = finished_game(puzzle, "Late tie", 3000, TODAY + 2.minutes)
    finished_game(puzzle, "Best", 4000, TODAY + 5.minutes)
    finished_game(puzzle, "Early tie", 3000, TODAY)
    Game.create!(puzzle:, player_name: "Unfinished", score: 4500)
    finished_game(Puzzle.for_date!(Date.new(2026, 10, 19)), "Yesterday", 5000, TODAY - 1.day)

    get "/api/leaderboard", params: { token: late_tie.token }

    body = response.parsed_body
    assert_equal "2026-10-20", body["puzzle_date"]
    assert_equal [
      { "rank" => 1, "player_name" => "Best", "score" => 4000, "you" => false },
      { "rank" => 2, "player_name" => "Early tie", "score" => 3000, "you" => false },
      { "rank" => 3, "player_name" => "Late tie", "score" => 3000, "you" => true }
    ], body["entries"].map { |entry| entry.except("completed_at") }
    assert_equal TODAY + 2.minutes, Time.iso8601(body["entries"][2]["completed_at"])
    assert_equal %w[completed_at player_name rank score you], body["entries"][0].keys.sort
  end

  test "the leaderboard shows the top 10 and nobody is you without a matching token" do
    puzzle = Puzzle.for_date!(Date.new(2026, 10, 20))
    12.times { |i| finished_game(puzzle, "Player #{i}", i * 100, TODAY) }

    get "/api/leaderboard", params: { token: "not-a-real-token" }

    entries = response.parsed_body["entries"]
    assert_equal (1..10).to_a, entries.map { |entry| entry["rank"] }
    assert_equal 1100, entries.first["score"]
    assert_equal 200, entries.last["score"]
    assert entries.none? { |entry| entry["you"] }
  end

  private

  def start_game(name = "Max")
    post "/api/games", params: { player_name: name }, as: :json
    response.parsed_body
  end

  def guess(token, position, value)
    post "/api/games/#{token}/rounds/#{position}/guess", params: { guess: value }, as: :json
    response.parsed_body
  end

  def play_rounds(token)
    (1..5).each { |position| guess(token, position, round_listing(token, position).sold_price) }
  end

  def play_full_game(name)
    start_game(name)["token"].tap { |token| play_rounds(token) }
  end

  def round_listing(token, position)
    Game.find_by!(token:).round_at!(position).listing
  end

  def finished_game(puzzle, name, score, completed_at)
    Game.create!(puzzle:, player_name: name, score:, completed_at:)
  end

  def assert_error_body
    assert_equal [ "error" ], response.parsed_body.keys
    assert_kind_of String, response.parsed_body["error"]
  end
end
