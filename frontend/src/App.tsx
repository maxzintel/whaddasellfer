import { type ReactNode, useCallback, useEffect, useReducer, useRef } from 'react'
import {
  clearSavedGame,
  createGame,
  getGame,
  getLeaderboard,
  HttpError,
  loadPlayerName,
  loadSavedGame,
  saveGame,
  savePlayerName,
  submitGuess,
} from './api'
import DevToolbar from './components/DevToolbar'
import ResultsScreen from './components/ResultsScreen'
import RevealScreen from './components/RevealScreen'
import RoundScreen from './components/RoundScreen'
import StartScreen from './components/StartScreen'
import { easternToday } from './format'
import { type Action, firstUnguessed, initialState, reducer, roundAt } from './game'

const messageOf = (e: unknown): string => (e instanceof Error ? e.message : 'Something went wrong.')

// Decide where to land on page load. Never throws; always resolves to an action.
async function runBoot(): Promise<Action> {
  const saved = loadSavedGame()
  if (!saved) return { type: 'boot/none' }
  try {
    const game = await getGame(saved.token)
    return { type: 'boot/loaded', game, today: easternToday() }
  } catch (e) {
    if (e instanceof HttpError && e.status === 404) {
      clearSavedGame()
      return { type: 'boot/none' }
    }
    return { type: 'boot/failed', message: messageOf(e) }
  }
}

export default function App() {
  const [state, dispatch] = useReducer(reducer, initialState)
  const { view, busy, error } = state
  // Guards against a second request starting before React re-renders with busy = true.
  const inFlight = useRef(false)

  useEffect(() => {
    let cancelled = false
    void runBoot().then((action) => {
      if (!cancelled) dispatch(action)
    })
    return () => {
      cancelled = true
    }
  }, [])

  // Fetch the leaderboard whenever we land on a screen that shows it.
  const screen = view.screen
  const leaderboardToken = view.screen === 'results' ? view.game.token : undefined
  useEffect(() => {
    if (screen !== 'start' && screen !== 'results') return
    let cancelled = false
    getLeaderboard(leaderboardToken).then(
      (leaderboard) => !cancelled && dispatch({ type: 'leaderboard/loaded', leaderboard }),
      (e: unknown) => !cancelled && dispatch({ type: 'leaderboard/failed', message: messageOf(e) }),
    )
    return () => {
      cancelled = true
    }
  }, [screen, leaderboardToken])

  // Each new screen (or round) starts at the top, which matters on phones.
  const position = 'position' in view ? view.position : 0
  useEffect(() => {
    window.scrollTo({ top: 0 })
  }, [screen, position])

  // Runs one game request at a time; failures become an inline error.
  const run = useCallback(async (task: () => Promise<Action>) => {
    if (inFlight.current) return
    inFlight.current = true
    dispatch({ type: 'request/started' })
    try {
      dispatch(await task())
    } catch (e) {
      dispatch({ type: 'request/failed', message: messageOf(e) })
    } finally {
      inFlight.current = false
    }
  }, [])

  const handleRetryBoot = () => run(runBoot)

  const handlePlay = (playerName: string) =>
    run(async () => {
      savePlayerName(playerName)
      const game = await createGame(playerName)
      saveGame(game.token)
      return { type: 'game/started', game }
    })

  const handleGuess = (token: string, roundPosition: number, guess: number) =>
    run(async () => {
      try {
        const game = await submitGuess(token, roundPosition, guess)
        return { type: 'guess/accepted', game, position: roundPosition }
      } catch (e) {
        // 422 can mean this round was already guessed (e.g. in another tab). If so, show its reveal
        // instead of leaving the player stuck on a round they can't submit.
        if (e instanceof HttpError && e.status === 422) {
          const fresh = await getGame(token).catch(() => null)
          if (fresh && roundAt(fresh, roundPosition)?.result) {
            return { type: 'guess/accepted', game: fresh, position: roundPosition }
          }
        }
        throw e
      }
    })

  let content: ReactNode = null
  switch (view.screen) {
    case 'boot':
      content = error ? (
        <article>
          <p role="alert">{error}</p>
          <button type="button" onClick={handleRetryBoot} disabled={busy}>
            Try again
          </button>
        </article>
      ) : (
        <p aria-busy="true">Loading…</p>
      )
      break

    case 'start':
      content = (
        <StartScreen
          today={easternToday()}
          defaultName={loadPlayerName()}
          busy={busy}
          error={error}
          leaderboard={state.leaderboard}
          leaderboardError={state.leaderboardError}
          onPlay={handlePlay}
        />
      )
      break

    case 'round': {
      const { game } = view
      const round = roundAt(game, view.position)
      if (round) {
        content = (
          <RoundScreen
            key={round.position}
            listing={round.listing}
            position={round.position}
            totalRounds={game.rounds.length}
            score={game.score}
            busy={busy}
            error={error}
            onGuess={(guess) => handleGuess(game.token, round.position, guess)}
          />
        )
      }
      break
    }

    case 'reveal': {
      const { game } = view
      const round = roundAt(game, view.position)
      if (round?.result) {
        content = (
          <RevealScreen
            round={{ ...round, result: round.result }}
            totalRounds={game.rounds.length}
            score={game.score}
            isLast={!firstUnguessed(game)}
            onNext={() => dispatch({ type: 'next' })}
          />
        )
      }
      break
    }

    case 'results':
      content = (
        <ResultsScreen game={view.game} leaderboard={state.leaderboard} leaderboardError={state.leaderboardError} />
      )
      break
  }

  return (
    <>
      <header>
        <hgroup>
          <h1>What'd It Sell For?</h1>
          <p>Guess the hammer price of real enthusiast-car auctions.</p>
        </hgroup>
      </header>

      {content}

      {import.meta.env.DEV && <DevToolbar />}
    </>
  )
}
