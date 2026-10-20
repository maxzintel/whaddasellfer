import { useState, type FormEvent } from 'react'
import { formatPuzzleDate } from '../format'
import type { Leaderboard as LeaderboardData } from '../types'
import Leaderboard from './Leaderboard'

const MAX_NAME_LENGTH = 30

type Props = {
  today: string
  defaultName: string
  busy: boolean
  error: string | null
  leaderboard: LeaderboardData | null
  leaderboardError: string | null
  onPlay: (playerName: string) => void
}

export default function StartScreen({ today, defaultName, busy, error, leaderboard, leaderboardError, onPlay }: Props) {
  const [name, setName] = useState(defaultName)
  const trimmed = name.trim()

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!trimmed || busy) return
    onPlay(trimmed)
  }

  return (
    <>
      <article>
        <header>
          <p>
            <strong>{formatPuzzleDate(today)}</strong>
          </p>
        </header>
        <p>
          Five real auction cars. Guess what each one sold for. The closer you are, the more points you get: up to
          1,000 per car, 5,000 total.
        </p>
        <form onSubmit={handleSubmit}>
          <label htmlFor="player-name">Your name</label>
          <input
            id="player-name"
            name="player_name"
            type="text"
            autoComplete="nickname"
            required
            maxLength={MAX_NAME_LENGTH}
            value={name}
            onChange={(e) => setName(e.target.value)}
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? 'start-error' : undefined}
          />
          {error && (
            <small id="start-error" role="alert">
              {error}
            </small>
          )}
          <button type="submit" disabled={busy || !trimmed} aria-busy={busy}>
            {busy ? 'Starting…' : 'Play'}
          </button>
        </form>
      </article>
      <Leaderboard leaderboard={leaderboard} error={leaderboardError} />
    </>
  )
}
