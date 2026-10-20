// API contract (see docs/DESIGN.md §5). Owned by the lead; lanes must not edit this file.

export type Hello = {
  message: string
  ruby: string
  rails: string
}

// Everything a player may see before guessing. Never includes the price or auction link.
export type PublicListing = {
  id: number
  year: number
  make: string
  model: string
  title: string
  mileage: number | null
  transmission: string | null
  body_style: string | null
  exterior_color: string | null
  interior_color: string | null
  title_status: string | null // null for most listings; hide the row when null
  highlights: string | null
  image_urls: string[]
}

// Present only once the round has been guessed.
export type RoundResult = {
  guess: number
  points: number // 0..1000
  sold_price: number
  pct_off: number // signed, 1 decimal: (guess - sold_price) / sold_price * 100. +13.0 = 13% high
  sold_at: string // ISO 8601
  source: string // e.g. "Bring a Trailer"
  source_url: string
}

export type Round = {
  position: number // 1..5
  listing: PublicListing
  result: RoundResult | null
}

export type Game = {
  token: string // the game's secret; the only way to read or play it
  player_name: string
  puzzle_date: string // YYYY-MM-DD, US Eastern
  score: number // 0..5000, sum of round points
  completed_at: string | null
  rounds: Round[] // always 5, ordered by position
}

export type LeaderboardEntry = {
  rank: number // 1-based; ties broken by earlier completed_at
  player_name: string
  score: number
  completed_at: string
  you: boolean // true when the request passed ?token= for this game
}

export type Leaderboard = {
  puzzle_date: string
  entries: LeaderboardEntry[] // top 10 completed games for today's puzzle
}

export type ApiError = { error: string }

// Dev toolbar only (POST /api/dev/reset_today exists in development and test, never production).
export type DevResetResult = {
  puzzle_date: string
  games_deleted: number
}
