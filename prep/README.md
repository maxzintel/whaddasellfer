# What'd It Sell For?

A "guess the hammer price" game. Each round shows a real sold enthusiast car (photos + specs). The player guesses the sale price and scores by closeness. 5 rounds per game, plus a leaderboard.

This is a 90-minute timeboxed build. Optimize for one complete, working loop over breadth. When in doubt, do less and ask.

## Layout

```
backend/    Rails 8, API-only, SQLite, Minitest
frontend/   Vite + React + TypeScript
data/       listings.csv (seed snapshot)
NOTES.md    running log of decisions and agent corrections (human-maintained)
```

## Commands

```
# from the repo root (pinned: Ruby 3.4.11 in backend/.ruby-version, Node 22.22.3 in .nvmrc)
npm run setup                           # check versions, bundle install, db:prepare, npm ci
npm run dev                             # Rails API on :3000 + Vite on :5173 (proxies /api -> :3000)
npm run check                           # backend tests + frontend lint + typecheck/build

cd backend && bin/rails db:setup        # migrate + seed from ../data/listings.csv
cd backend && bin/rails test            # Minitest only
```

## Domain model

- `Listing`: read-only seed data. Columns match `data/listings.csv` headers 1:1: source_id, year, make, model, title, mileage, transmission, body_style, exterior_color, interior_color, title_status, highlights (seller description text; engine/drivetrain live in here), image_urls (JSON array of 4–6 URLs), sold_price (integer dollars), sold_at, source, source_url. There is no trim, engine, drivetrain, or location column in the source data.
- `Game`: player_name, score (int, default 0), completed_at. has_many :rounds.
- `Round`: game_id, listing_id, position (1–5), guess (int, nullable), points (int, nullable), guessed_at. All 5 rounds are created when the game starts. Unique indexes on [game_id, position] and [game_id, listing_id].

## API (all under /api, JSON)

- `POST /api/games` with `{player_name}` → creates the game + 5 rounds of random listings.
- `GET /api/games/:id` → game, score, rounds.
- `POST /api/games/:game_id/rounds/:id/guess` with `{guess}` → scores the round under `round.with_lock`, then updates game score and sets completed_at after the final round. 422 if already guessed or guess <= 0.
- `GET /api/leaderboard` → top 10 completed games by score.

## Hard rules

1. **Never expose `sold_price` for an unguessed round.** Serialize listings through an explicit allowlist (`Listing#public_attributes`), never `as_json(except: ...)`. Only a guessed round may include `sold_price` and `points`. There must be an integration test asserting this.
2. Scoring lives in a plain Ruby module `Scoring.points(guess:, actual:)` with unit tests. v1 formula: `max(0, round(1000 * (1 - 2 * |guess - actual| / actual)))`.
3. Business logic goes in models or POROs. Controllers stay thin.
4. Return errors as `{ error: "message" }` with the right status code (404, 422).
5. Don't add gems or npm packages without asking first. Pre-approved: `csv` (on Ruby 3.4 it is a bundled gem, so it must be added with `bundle add csv` or `require "csv"` fails). Don't add rack-cors; the Vite proxy handles it.

## Out of scope: do not build unless explicitly asked

Auth/accounts, Action Cable/real-time, Redux or any state library, react-router, an admin UI, deployment config, Docker, or a component library. Players identify by a typed name only.

## Frontend conventions

- No router. One `useReducer` state machine: `start → round → reveal → … → results`.
- All fetches go through `src/api.ts`. Types for API payloads live in `src/types.ts`.
- Styling: classless Pico.css via CDN link in `index.html`, or minimal plain CSS. No CSS frameworks via npm.
- Format money with `Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 })`.

## How to work in this repo

- Work in small slices. Propose a short plan before writing code for any slice, and wait for approval.
- After each backend change, run `bin/rails test` and report the result.
- Keep diffs focused. Don't refactor or reformat files outside the current slice.
- If something is ambiguous, ask one question rather than guessing big.
- Don't edit NOTES.md; the human maintains it.

## Feature & Other Ideas:
1. Like Wordle, every 'day' should be the same 5 cars for everyone
2. You can play without an account, but you can't track stats without one
3. Prevent users from playing other 'days' games (potential reach feature would be premium users who can play past games)

## Ambitious Additions:
1. When the price is revealed, show comparable sales: “7 other E46 M3s (±3 years) sold for a median of $27,800. This one went 13% over.” At the end of the game, add a calibration readout: “You guessed 14% high on average. Your worst miss was the 911 SC at 41% off.”

Why this one over the alternatives:

It turns a guessing game into a market-sense tool. That’s the actual MaxFindsCars thesis, and it’s the most on-domain thing you could show an auction company.
It’s all deterministic Rails: a comps scope (same make/model, year window, excluding this listing), a median computed in Ruby (SQLite has no median), and calibration as the average log-ratio of the guesses. None of it touches the core loop, and it’s straightforward to test.
It has real edge cases to discuss: zero comps, one comp, comps outliers.

2. Social virality stuff
  - sharing with some sort of tile thing like wordle
3. Hardening & polish
  - make sure the same auction isn't used more than once
  -