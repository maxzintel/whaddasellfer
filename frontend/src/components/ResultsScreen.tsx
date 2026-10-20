import { formatMoney, formatPctOff, formatPoints, formatPuzzleDate } from '../format'
import type { Game, Leaderboard as LeaderboardData } from '../types'
import Leaderboard from './Leaderboard'
import ShareCard from './ShareCard'

type Props = {
  game: Game
  leaderboard: LeaderboardData | null
  leaderboardError: string | null
}

export default function ResultsScreen({ game, leaderboard, leaderboardError }: Props) {
  const maxScore = game.rounds.length * 1000

  return (
    <>
      <article>
        <header>
          <p>
            <strong>{formatPuzzleDate(game.puzzle_date)}</strong> · {game.player_name}
          </p>
        </header>
        <p>Your score</p>
        <p className="big-number">
          {formatPoints(game.score)} <small>/ {formatPoints(maxScore)}</small>
        </p>

        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th scope="col">Car</th>
                <th scope="col" className="num">
                  Your guess
                </th>
                <th scope="col" className="num">
                  Sold for
                </th>
                <th scope="col">Off by</th>
                <th scope="col" className="num">
                  Points
                </th>
              </tr>
            </thead>
            <tbody>
              {game.rounds.map(({ position, listing, result }) => (
                <tr key={position}>
                  <td>{listing.title}</td>
                  <td className="num">{result ? formatMoney(result.guess) : '–'}</td>
                  <td className="num">{result ? formatMoney(result.sold_price) : '–'}</td>
                  <td>{result ? formatPctOff(result.pct_off) : '–'}</td>
                  <td className="num">{result ? formatPoints(result.points) : '–'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <ShareCard game={game} />

        <footer>
          <p>New cars tomorrow at midnight ET.</p>
        </footer>
      </article>
      <Leaderboard leaderboard={leaderboard} error={leaderboardError} />
    </>
  )
}
