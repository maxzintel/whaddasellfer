import { useState, type FormEvent } from 'react'
import { formatMileage, formatMoney, formatPoints, formatSpec, parseGuess } from '../format'
import type { PublicListing } from '../types'
import PhotoGallery from './PhotoGallery'

type Props = {
  listing: PublicListing
  position: number
  totalRounds: number
  score: number
  busy: boolean
  error: string | null
  onGuess: (guess: number) => void
}

// Specs to show, skipping anything the listing doesn't have.
function specRows(listing: PublicListing): [string, string][] {
  const rows: [string, string | null][] = [
    ['Mileage', listing.mileage === null ? null : formatMileage(listing.mileage)],
    ['Transmission', listing.transmission && formatSpec(listing.transmission)],
    ['Body style', listing.body_style && formatSpec(listing.body_style)],
    ['Exterior', listing.exterior_color && formatSpec(listing.exterior_color)],
    ['Interior', listing.interior_color && formatSpec(listing.interior_color)],
    ['Title', listing.title_status && formatSpec(listing.title_status)],
  ]
  return rows.filter((row): row is [string, string] => Boolean(row[1]))
}

export default function RoundScreen({ listing, position, totalRounds, score, busy, error, onGuess }: Props) {
  const [input, setInput] = useState('')
  const guess = parseGuess(input)
  const canSubmit = !busy && guess !== null && guess > 0
  const specs = specRows(listing)

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (canSubmit) onGuess(guess)
  }

  return (
    <article>
      <header>
        <p>
          Round {position} of {totalRounds} · Score {formatPoints(score)}
        </p>
      </header>

      <PhotoGallery key={listing.id} urls={listing.image_urls} title={listing.title} />

      <h2>{listing.title}</h2>
      {specs.length > 0 && (
        <dl className="specs">
          {specs.map(([label, value]) => (
            <div key={label}>
              <dt>{label}</dt>
              <dd>{value}</dd>
            </div>
          ))}
        </dl>
      )}
      {listing.highlights && <p className="highlights">{listing.highlights}</p>}

      <form onSubmit={handleSubmit}>
        <label htmlFor="guess">What did it sell for?</label>
        <input
          id="guess"
          name="guess"
          type="text"
          inputMode="numeric"
          autoComplete="off"
          placeholder="$25,000"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          aria-invalid={error ? true : undefined}
          aria-describedby={error ? 'guess-preview guess-error' : 'guess-preview'}
        />
        <small id="guess-preview" aria-live="polite">
          {guess !== null && guess > 0 ? `Your guess: ${formatMoney(guess)}` : 'Enter a dollar amount.'}
        </small>
        {error && (
          <small id="guess-error" role="alert">
            {error}
          </small>
        )}
        <button type="submit" disabled={!canSubmit} aria-busy={busy}>
          {busy ? 'Submitting…' : 'Lock it in'}
        </button>
      </form>
    </article>
  )
}
