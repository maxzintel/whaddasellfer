import { useState } from 'react'

type Props = { urls: string[]; title: string }

// One big photo plus a strip of clickable thumbnails. Key this by listing so it resets per car.
export default function PhotoGallery({ urls, title }: Props) {
  const [selected, setSelected] = useState(0)

  if (urls.length === 0) return <p>No photos for this one. Trust your gut.</p>

  const current = Math.min(selected, urls.length - 1)

  return (
    <figure className="gallery">
      <img
        className="gallery-main"
        src={urls[current]}
        alt={`${title}, photo ${current + 1} of ${urls.length}`}
      />
      {urls.length > 1 && (
        <div className="gallery-thumbs">
          {urls.map((url, i) => (
            <button
              key={`${i}:${url}`}
              type="button"
              className="gallery-thumb"
              aria-label={`Show photo ${i + 1} of ${urls.length}`}
              aria-pressed={i === current}
              onClick={() => setSelected(i)}
            >
              <img src={url} alt="" loading="lazy" />
            </button>
          ))}
        </div>
      )}
    </figure>
  )
}
