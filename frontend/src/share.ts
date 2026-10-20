// Wordle-style share text for the results screen. Spoiler-free on purpose: no car names,
// prices or guesses, because friends play the same 5 cars that day. Never put the game
// token in here; it would let anyone who sees the message play (and wreck) your game.
import { formatPoints } from './format'
import type { Game } from './types'

export const SHARE_URL = 'https://whaddasellfer.com' // placeholder; we don't own this domain
export const LAUNCH_DATE = '2026-10-20' // puzzle #1

const DAY_MS = 24 * 60 * 60 * 1000

const utcDay = (isoDate: string): number => {
  const [y, m, d] = isoDate.split('-').map(Number)
  return Date.UTC(y, m - 1, d)
}

// Points map straight onto % off (DESIGN §3): 800+ is within 10%, 400+ within 30%,
// anything above 0 within 50%. An unguessed round (shouldn't happen on results) is blank.
export function roundEmoji(points: number | null): string {
  if (points === null) return '⬜'
  if (points >= 800) return '🟩'
  if (points >= 400) return '🟨'
  if (points > 0) return '🟧'
  return '🟥'
}

export const EMOJI_LEGEND = '🟩 within 10% · 🟨 within 30% · 🟧 within 50% · 🟥 50%+ off'

// Day count since launch, so 2026-10-20 is #1. Calendar math in UTC so DST never shifts it.
export const puzzleNumber = (puzzleDate: string): number =>
  Math.round((utcDay(puzzleDate) - utcDay(LAUNCH_DATE)) / DAY_MS) + 1

// "What'd It Sell For? #1 · Oct 20" / "3,412 / 5,000" / "🟩🟨🟩🟥🟧" / link
export function buildShareText(game: Game): string {
  const number = puzzleNumber(game.puzzle_date)
  const date = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' }).format(
    utcDay(game.puzzle_date),
  )
  const title = number >= 1 ? `What'd It Sell For? #${number} · ${date}` : `What'd It Sell For? · ${date}`
  const grid = game.rounds.map((round) => roundEmoji(round.result?.points ?? null)).join('')

  return [title, `${formatPoints(game.score)} / ${formatPoints(game.rounds.length * 1000)}`, grid, SHARE_URL].join('\n')
}
