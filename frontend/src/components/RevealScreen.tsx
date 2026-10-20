import { formatMoney, formatPctOff, formatPoints, formatSoldDate } from '../format'
import type { Round, RoundResult } from '../types'

type Props = {
  round: Round & { result: RoundResult }
  totalRounds: number
  score: number
  isLast: boolean
  onNext: () => void
}

export default function RevealScreen({ round, totalRounds, score, isLast, onNext }: Props) {
  const { listing, result } = round

  return (
    <article>
      <header>
        <p>
          Round {round.position} of {totalRounds} · Score {formatPoints(score)}
        </p>
      </header>

      {listing.image_urls[0] && (
        <figure className="gallery">
          <img className="gallery-main" src={listing.image_urls[0]} alt={listing.title} />
        </figure>
      )}

      <h2>{listing.title}</h2>
      <p>Sold for</p>
      <p className="big-number">{formatMoney(result.sold_price)}</p>

      <dl className="specs">
        <div>
          <dt>Your guess</dt>
          <dd>{formatMoney(result.guess)}</dd>
        </div>
        <div>
          <dt>Off by</dt>
          <dd>{formatPctOff(result.pct_off)}</dd>
        </div>
        <div>
          <dt>Points</dt>
          <dd>
            <strong>{formatPoints(result.points)}</strong> / 1,000
          </dd>
        </div>
      </dl>

      <p>
        Sold on {result.source}, {formatSoldDate(result.sold_at)}.{' '}
        <a href={result.source_url} target="_blank" rel="noopener noreferrer">
          See the auction
        </a>
      </p>

      <footer>
        {/* Focus Next so Enter keeps the game moving after submitting a guess. */}
        <button type="button" onClick={onNext} autoFocus>
          {isLast ? 'See results' : 'Next car'}
        </button>
      </footer>
    </article>
  )
}
