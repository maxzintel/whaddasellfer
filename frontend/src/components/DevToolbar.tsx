import { useState } from 'react'
import { clearPlayerName, clearSavedGame, devResetToday } from '../api'

// Local testing tools. App renders this only when import.meta.env.DEV is true, so
// production builds drop it. Both actions reload the page so the game boots from scratch.
export default function DevToolbar() {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Same puzzle, new player: forget this browser's game and name.
  function newPlayer() {
    clearSavedGame()
    clearPlayerName()
    window.location.reload()
  }

  // New puzzle, empty leaderboard: wipe today on the server, then start over.
  async function resetToday() {
    if (!window.confirm("Delete today's puzzle and every game played today?")) return
    setBusy(true)
    setError(null)
    try {
      await devResetToday()
      clearSavedGame()
      window.location.reload()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Reset failed.')
      setBusy(false)
    }
  }

  return (
    <aside className="dev-toolbar" aria-label="Developer tools">
      <small>
        <strong>Dev</strong>
      </small>
      <button type="button" onClick={newPlayer} disabled={busy}>
        New player
      </button>
      <button type="button" onClick={resetToday} disabled={busy} aria-busy={busy}>
        Reset today
      </button>
      {error && <small role="alert">{error}</small>}
    </aside>
  )
}
