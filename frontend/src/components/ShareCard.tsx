import { useEffect, useState } from 'react'
import { buildShareText, EMOJI_LEGEND } from '../share'
import type { Game } from '../types'

type Status = 'idle' | 'copied' | 'failed'

// Shows the share text and copies it to the clipboard. If the clipboard is blocked,
// the preview stays selectable so the player can copy it by hand.
export default function ShareCard({ game }: { game: Game }) {
  const [status, setStatus] = useState<Status>('idle')
  const text = buildShareText(game)

  // Let "Copied!" fade back to the normal label so the button can be used again.
  useEffect(() => {
    if (status !== 'copied') return
    const timer = window.setTimeout(() => setStatus('idle'), 2500)
    return () => window.clearTimeout(timer)
  }, [status])

  async function handleShare() {
    try {
      await navigator.clipboard.writeText(text)
      setStatus('copied')
    } catch {
      setStatus('failed')
    }
  }

  return (
    <section aria-labelledby="share-heading">
      <h3 id="share-heading">Challenge your friends</h3>
      <pre className="share-preview">{text}</pre>
      <small>{EMOJI_LEGEND}</small>
      <button type="button" onClick={handleShare}>
        {status === 'copied' ? 'Copied! Paste it anywhere' : 'Share your score'}
      </button>
      <small role="status">
        {status === 'failed' ? "Couldn't copy automatically. Select the text above and copy it." : ''}
      </small>
    </section>
  )
}
