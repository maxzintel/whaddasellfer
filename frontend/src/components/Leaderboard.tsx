import { formatPoints } from '../format'
import type { Leaderboard as LeaderboardData } from '../types'

type Props = { leaderboard: LeaderboardData | null; error: string | null }

export default function Leaderboard({ leaderboard, error }: Props) {
  return (
    <section aria-labelledby="leaderboard-heading">
      <h2 id="leaderboard-heading">Today's leaderboard</h2>
      {error && !leaderboard && <p>Couldn't load the leaderboard: {error}</p>}
      {!error && !leaderboard && <p aria-busy="true">Loading leaderboard…</p>}
      {leaderboard && leaderboard.entries.length === 0 && <p>No finished games yet today. Be the first!</p>}
      {leaderboard && leaderboard.entries.length > 0 && (
        <div className="table-scroll">
          <table>
            <thead>
              <tr>
                <th scope="col">#</th>
                <th scope="col">Player</th>
                <th scope="col" className="num">
                  Score
                </th>
              </tr>
            </thead>
            <tbody>
              {leaderboard.entries.map((entry) => (
                <tr key={`${entry.rank}-${entry.player_name}-${entry.completed_at}`} className={entry.you ? 'you' : undefined}>
                  <td>{entry.rank}</td>
                  <td>
                    {entry.player_name}
                    {entry.you && <strong> (you)</strong>}
                  </td>
                  <td className="num">{formatPoints(entry.score)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
