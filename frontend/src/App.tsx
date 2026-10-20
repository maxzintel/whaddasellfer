import { useEffect, useState } from 'react'
import { getHello } from './api'
import type { Hello } from './types'

export default function App() {
  const [hello, setHello] = useState<Hello | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    getHello().then(setHello).catch((e: Error) => setError(e.message))
  }, [])

  return (
    <main>
      <h1>What'd It Sell For?</h1>
      {error && <p>Backend error: {error}</p>}
      {!error && !hello && <p>Loading…</p>}
      {hello && (
        <p>
          {hello.message} (Ruby {hello.ruby}, Rails {hello.rails})
        </p>
      )}
    </main>
  )
}
