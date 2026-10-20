// Every network call and every localStorage access goes through this file.
import type { Game, Leaderboard } from './types'

// An API failure. `status` is the HTTP status, or 0 when the server couldn't be reached.
export class HttpError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'HttpError'
    this.status = status
  }
}

async function request<T>(method: 'GET' | 'POST', path: string, body?: unknown): Promise<T> {
  let res: Response
  try {
    res = await fetch(path, {
      method,
      headers: body === undefined
        ? { Accept: 'application/json' }
        : { Accept: 'application/json', 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new HttpError("Couldn't reach the server. Check your connection and try again.", 0)
  }

  // Not every failure has a JSON body (e.g. the dev proxy when Rails is down), so parse defensively.
  const text = await res.text()
  let data: unknown = null
  if (text) {
    try {
      data = JSON.parse(text)
    } catch {
      data = null
    }
  }

  if (!res.ok) {
    const message = (data as { error?: unknown } | null)?.error
    if (typeof message === 'string') throw new HttpError(message, res.status)
    if (res.status >= 500) {
      throw new HttpError(`The server isn't responding right now (${res.status}). Try again in a moment.`, res.status)
    }
    throw new HttpError(`Request failed: ${res.status}`, res.status)
  }
  return data as T
}

const enc = encodeURIComponent

export const createGame = (playerName: string) =>
  request<Game>('POST', '/api/games', { player_name: playerName })

export const getGame = (token: string) => request<Game>('GET', `/api/games/${enc(token)}`)

export const submitGuess = (token: string, position: number, guess: number) =>
  request<Game>('POST', `/api/games/${enc(token)}/rounds/${position}/guess`, { guess })

export const getLeaderboard = (token?: string) =>
  request<Leaderboard>('GET', token ? `/api/leaderboard?token=${enc(token)}` : '/api/leaderboard')

// --- localStorage (any access can throw, e.g. in private mode or with storage blocked) ---

const GAME_KEY = 'wisf.game'
const NAME_KEY = 'wisf.playerName'

export type SavedGame = { token: string }

export function loadSavedGame(): SavedGame | null {
  try {
    const raw = localStorage.getItem(GAME_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw) as Partial<SavedGame> | null
    return typeof parsed?.token === 'string' && parsed.token ? { token: parsed.token } : null
  } catch {
    return null
  }
}

export function saveGame(token: string): void {
  try {
    localStorage.setItem(GAME_KEY, JSON.stringify({ token } satisfies SavedGame))
  } catch {
    // Storage unavailable: the game still works, it just can't be resumed after a reload.
  }
}

export function clearSavedGame(): void {
  try {
    localStorage.removeItem(GAME_KEY)
  } catch {
    // Nothing to clear.
  }
}

export function loadPlayerName(): string {
  try {
    return localStorage.getItem(NAME_KEY) ?? ''
  } catch {
    return ''
  }
}

export function savePlayerName(name: string): void {
  try {
    localStorage.setItem(NAME_KEY, name)
  } catch {
    // Storage unavailable: the name just won't be prefilled next time.
  }
}
