// The game's state machine: a pure reducer plus its state and action types (DESIGN §6).
// No fetching and no clock reads here; App runs the effects and passes results in as actions.
//
//   boot ──(saved game?)──► round | results | start
//   start ──started──► round(n) ──guessed──► reveal(n) ──next──► round(n+1) … ──► results
//
// The server's Game is the source of truth. Every API response replaces the stored game, and
// the current round is always worked out from it (the first round whose result is null).
import type { Game, Leaderboard, Round } from './types'

export type View =
  | { screen: 'boot' }
  | { screen: 'start' }
  | { screen: 'round'; game: Game; position: number }
  | { screen: 'reveal'; game: Game; position: number } // the round just guessed
  | { screen: 'results'; game: Game }

export type State = {
  view: View
  busy: boolean // a game request is in flight; blocks double submits
  error: string | null // shown inline on the current screen
  leaderboard: Leaderboard | null
  leaderboardError: string | null
}

export type Action =
  // Boot found nothing usable (no saved token, or the server said 404).
  | { type: 'boot/none' }
  // Boot loaded the saved game. `today` is the US Eastern date (YYYY-MM-DD).
  | { type: 'boot/loaded'; game: Game; today: string }
  // Boot couldn't reach the server; stay on boot and show a retry.
  | { type: 'boot/failed'; message: string }
  | { type: 'request/started' }
  | { type: 'request/failed'; message: string }
  | { type: 'game/started'; game: Game }
  | { type: 'guess/accepted'; game: Game; position: number }
  | { type: 'next' }
  | { type: 'leaderboard/loaded'; leaderboard: Leaderboard }
  | { type: 'leaderboard/failed'; message: string }

export const initialState: State = {
  view: { screen: 'boot' },
  busy: false,
  error: null,
  leaderboard: null,
  leaderboardError: null,
}

export const firstUnguessed = (game: Game): Round | undefined =>
  game.rounds.find((r) => r.result === null)

export const roundAt = (game: Game, position: number): Round | undefined =>
  game.rounds.find((r) => r.position === position)

// Where a game belongs: its first unguessed round, or results once all are guessed.
export function viewForGame(game: Game): View {
  const next = firstUnguessed(game)
  return next ? { screen: 'round', game, position: next.position } : { screen: 'results', game }
}

const settled = (state: State, view: View): State => ({ ...state, view, busy: false, error: null })

export function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'boot/none':
      return settled(state, { screen: 'start' })

    case 'boot/loaded': {
      const { game, today } = action
      // An unfinished game resumes even if it started yesterday (finishing late is allowed, D3).
      if (firstUnguessed(game)) return settled(state, viewForGame(game))
      // A finished game shows results only on its own day; a new day means new cars.
      if (game.puzzle_date === today) return settled(state, { screen: 'results', game })
      return settled(state, { screen: 'start' })
    }

    case 'boot/failed':
      return { ...state, view: { screen: 'boot' }, busy: false, error: action.message }

    case 'request/started':
      return { ...state, busy: true, error: null }

    case 'request/failed':
      return { ...state, busy: false, error: action.message }

    case 'game/started':
      return settled(state, viewForGame(action.game))

    case 'guess/accepted': {
      const round = roundAt(action.game, action.position)
      // If the response somehow doesn't show the round as guessed, fall back to wherever the game is.
      if (!round?.result) return settled(state, viewForGame(action.game))
      return settled(state, { screen: 'reveal', game: action.game, position: action.position })
    }

    case 'next': {
      if (state.view.screen !== 'reveal') return state
      const view = viewForGame(state.view.game)
      // Drop the start screen's leaderboard so results never show it without your row marked.
      if (view.screen === 'results') return { ...settled(state, view), leaderboard: null, leaderboardError: null }
      return settled(state, view)
    }

    case 'leaderboard/loaded':
      return { ...state, leaderboard: action.leaderboard, leaderboardError: null }

    case 'leaderboard/failed':
      return { ...state, leaderboardError: action.message }
  }
}
