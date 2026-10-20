# Builds the Game payload in frontend/src/types.ts. The listing block always goes
# through Listing#public_attributes; price and auction details appear only in a
# guessed round's `result`. No integer game or round ids, ever: the token is the key.
class GameSerializer
  def initialize(game)
    @game = game
  end

  def as_json(*)
    {
      token: @game.token,
      player_name: @game.player_name,
      puzzle_date: @game.puzzle.puzzle_date.iso8601,
      score: @game.score,
      completed_at: @game.completed_at,
      rounds: @game.rounds.includes(:listing).map { |round| round_json(round) }
    }
  end

  private

  def round_json(round)
    { position: round.position, listing: round.listing.public_attributes, result: result_json(round) }
  end

  def result_json(round)
    return nil unless round.guessed?

    sold_price = round.listing.sold_price
    {
      guess: round.guess,
      points: round.points,
      pct_off: ((round.guess - sold_price) * 100.0 / sold_price).round(1)
    }.merge(round.listing.reveal_attributes.symbolize_keys)
  end
end
