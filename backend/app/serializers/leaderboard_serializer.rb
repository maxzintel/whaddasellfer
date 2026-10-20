# Builds the Leaderboard payload in frontend/src/types.ts for one day.
# Never includes tokens; `you` marks the row whose token the caller passed.
class LeaderboardSerializer
  def initialize(date:, token: nil)
    @date = date
    @token = token if token.is_a?(String) && token.present?
  end

  def as_json(*)
    { puzzle_date: @date.iso8601, entries: }
  end

  private

  def entries
    # A GET never creates the day's puzzle: no puzzle yet means no entries yet.
    puzzle = Puzzle.find_by(puzzle_date: @date)
    return [] unless puzzle

    Game.leaderboard(puzzle).each.with_index(1).map do |game, rank|
      {
        rank:,
        player_name: game.player_name,
        score: game.score,
        completed_at: game.completed_at,
        you: @token.present? && ActiveSupport::SecurityUtils.secure_compare(game.token, @token)
      }
    end
  end
end
