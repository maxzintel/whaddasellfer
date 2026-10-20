# What'd It Sell For? — v1 Design

Status: **decisions agreed 2026-10-20** · Timebox: 90 min · Rules come from `prep/README.md`, except where Max's brief overrides it. The main override: same 5 cars for everyone each day, instead of 5 random cars per game. Accepted gaps are tracked in [`known-limitations.md`](known-limitations.md).

## 1. Goal and scope

One complete loop: type a name → play **today's** 5 cars → see each real price after guessing → final score → today's leaderboard. Same 5 cars for everyone on a given day.

**In v1:** daily puzzle, 5-round game, scoring, reveal, results, daily leaderboard, resume an in-progress game after refresh.

**Not in v1** (README "Ambitious Additions" + out-of-scope list): comps/calibration readout, share tiles, accounts/stats, playing past days, auth, real-time, router, state library, admin, deploy.

## 2. What the data gives us (and doesn't)

Profiled `data/listings.csv`: 200 rows, all with price/mileage/4–6 images; 161 BaT, 38 Cars & Bids, 1 PCarMarket; prices $3,000 – $393,500 (median $25,000).

| Prompt asks for | In the data? | v1 plan |
|---|---|---|
| Photos, year, model, mileage | Yes | Show |
| Key specs | Partly: transmission, body style, colors. Engine/drivetrain only inside `highlights` text | Show columns + highlights paragraph as-is. No text parsing |
| Location | **No column** | Not shown (D4). `title_status` is shown only when present (39 C&B rows), hidden otherwise |
| Highlights | Yes, 100–450 chars of seller text. Checked: no dollar amounts in any row | Show |

Dev DB has no app tables yet (only Rails metadata), so migrations and seeding are part of the foundation work.

## 3. Key decisions and why

### SQLite, not Postgres
**Why SQLite now**
- **It's already wired in.** `database.yml`, the `sqlite3` gem, and `bin/setup`'s `db:prepare` all work today. Postgres *is* running on this machine (`:5432`), but switching means adding the `pg` gem (needs approval under README rule 5), creating a role and two databases, and changing `database.yml` and `bin/setup`. It also means anyone else who runs the repo needs a Postgres server. That's roughly 10 minutes of setup that doesn't touch the game, plus a new way for `npm run setup` to fail.
- **The workload is tiny and mostly reads.** 200 listings that never change. About 7 writes per game (1 game row, 5 rounds, then 1 score update per guess). SQLite allows only one writer at a time, but each write takes about a millisecond on local disk, and `timeout: 5000` makes a busy writer wait instead of erroring. That covers hundreds of writes per second.
- **The two concurrency risks are solved the same way on both databases.** Double guesses and puzzle creation (below) are guarded by unique indexes and transactions. Rails 8.1 starts every SQLite transaction as `BEGIN IMMEDIATE` (verified in `activerecord-8.1.4`), which takes the database's write lock up front. SQLite drops the `FOR UPDATE` part of `with_lock`, but because the whole transaction holds that lock, two guesses on one round still run one after the other.
- **Tests are fast and isolated.** The database runs inside the Ruby process. Each parallel test worker gets its own file.

**When Postgres wins (what would make us switch)**
- **More than one app server.** A SQLite file lives on one machine's disk. Hosts with throwaway disks (Heroku, Render, most serverless platforms) or any horizontal scaling need a database over the network. **This is the real trigger.**
- **Write contention on a busy day.** Thousands of guesses at once would queue behind the single writer. Postgres's row-level locks let unrelated games write in parallel.
- **Running it as a real service:** managed backups and point-in-time restore, read replicas, plugging in BI tools.
- **Sharing data with MaxFindsCars.** If the game should later read listings live from MFC's database, use whatever MFC runs.

**Cost of switching later:** low before launch. We write no SQLite-specific SQL (`RANDOM()` also exists in Postgres), the migrations are portable, and listings re-seed from the CSV. After launch, you'd also move the games and rounds data.

### Daily puzzle: a stored `Puzzle` row, created on first request
Options considered:

| Option | Pros | Cons |
|---|---|---|
| **A. `Puzzle` table, created the first time anyone starts a game that day** ✅ | Fixed once picked. We can look up which cars ran on a given day. Can avoid repeating cars. No scheduler | 2 more tables. Two people starting at the same moment could both try to create it (handled below) |
| B. Shuffle seeded by the date, nothing stored | No schema | Re-seeding or adding listings silently changes past and present days. Cars repeat across days. Harder to test |
| C. Rake task pre-builds a schedule | Easy to reason about | Needs a scheduler or manual step. Fails silently if it isn't run |

**Race: two players start at the same moment on a new day.** The database's unique index is the real guard, not the app code's "does it exist yet?" check.

```ruby
def self.for_date!(date)
  find_by(puzzle_date: date) || create_with_listings!(date)   # transaction: puzzle + 5 puzzle_listings
rescue ActiveRecord::RecordNotUnique
  find_by!(puzzle_date: date)                                  # loser re-reads the winner's row
end
```

1. A and B both run `find_by` and get nothing.
2. A opens its transaction first and takes SQLite's write lock (`BEGIN IMMEDIATE`). B waits (up to `timeout: 5000`ms).
3. A inserts the puzzle and its 5 listings, then commits.
4. B gets the lock and inserts a puzzle with the same `puzzle_date`. The unique index rejects it with `RecordNotUnique`. B's whole transaction rolls back, so B leaves no half-built puzzle or orphaned rows.
5. B's `rescue` runs `find_by!` and gets A's puzzle. **Both games use the same 5 cars.**

The `rescue` sits *outside* the transaction on purpose. On Postgres, a failed statement poisons the rest of its transaction, so the re-read must happen after the rollback. Writing it this way keeps it portable. Racers may each *pick* different cars, but only the committed pick survives. Test: stub the first `find_by` to return nil after another puzzle has been inserted, then assert the existing puzzle comes back and only one puzzle exists. (Real threads plus SQLite plus parallel tests would be flaky.)

**Picking the 5:** random sample of listings **not used in any earlier puzzle**. If fewer than 5 unused remain, fall back to all listings. 200 listings / 5 = 40 days before any repeat. It costs one `where.not`, so it's included (D2).

### What counts as "a day"
Puzzle date = `Time.zone.today` with `config.time_zone = "Eastern Time (US & Canada)"`. The server picks the day, never the client, and no endpoint accepts a date, so players **can't reach other days' puzzles** (README idea #3, for free). Tradeoff vs Wordle: Wordle flips at each player's local midnight. We flip at midnight Eastern for everyone, so a player in London gets new cars at 5am (D1, logged in known-limitations).

A game started at 11:58pm can still be finished after midnight. Its score counts on the board of the day it started. This is a lenient choice (D3).

### One game per player per day
Without accounts we can't truly enforce this. v1 makes it the default path: the frontend saves `{date, gameId}` in `localStorage`. On load, if today's game exists it **resumes** (or shows results) instead of offering a new game. The game token (below) is what's stored. A determined player can clear storage or change the name and replay with the answers known. That's a known gap until accounts exist.

### Never leak the price
- `Listing#public_attributes` is an **explicit allowlist**: `id, year, make, model, title, mileage, transmission, body_style, exterior_color, interior_color, title_status, highlights, image_urls`.
- Hidden until the round is guessed: `sold_price`, plus **`source_url`** (the auction page shows the price), `source_id` (searchable), `sold_at`, `source`.
- A guessed round adds a separate `result` object. The listing block looks the same before and after a guess, so there's one place to audit.
- Integration test: start a game, walk the full JSON, assert no `sold_price`/`source_url` key appears for any unguessed round. After guessing round 1, assert only round 1 has them.
- Known gap: image URLs are hosted on the auction sites (`bringatrailer.com/wp-content/uploads/2025/11/…`), so a curious player can see the source and month. Fixing that would mean serving images through our own server. Not in v1.

### Scoring
`Scoring.points(guess:, actual:) = max(0, round(1000 * (1 - 2*|guess-actual|/actual)))`, computed with `Rational` so floats never round wrong. Max 1,000 per round, 5,000 per game. Being ±50% off or worse scores 0. Note: it's harsher on high guesses than low ones at the same ratio (guessing 1.5× the price scores 0, but the mirror-image low guess, ⅔× the price, still scores 333). That's fine for v1, and worth knowing for tuning later.

`Game#score` is **recomputed** as the sum of round points, never incremented. If something runs twice, the total stays right.

## 4. Data model

```
listings          (seed, read-only; columns 1:1 with CSV)
  source_id string UNIQUE · year int · make · model · title · mileage int
  transmission · body_style · exterior_color · interior_color · title_status (nullable)
  highlights text · image_urls json · sold_price int · sold_at datetime · source · source_url

puzzles           puzzle_date date UNIQUE
puzzle_listings   puzzle_id FK · listing_id FK · position 1..5
                  UNIQUE [puzzle_id, position] · UNIQUE [puzzle_id, listing_id]

games             puzzle_id FK · token string UNIQUE (has_secure_token) · player_name string(1..30)
                  score int default 0 · completed_at datetime null
                  INDEX [puzzle_id, completed_at, score]   (daily leaderboard)
rounds            game_id FK · listing_id FK · position 1..5 · guess int null · points int null · guessed_at null
                  UNIQUE [game_id, position] · UNIQUE [game_id, listing_id]
```

Changes from the README model: `games.puzzle_id` and `games.token`. Rounds are still all created at game start, copied from the puzzle's listings in order.

**Seeds** (`db/seeds.rb`): read `../data/listings.csv` and `upsert_all` keyed on `source_id`, so re-running is safe. `image_urls` is parsed from JSON. `""` becomes `nil` for `title_status`. `sold_at` is parsed with its offset. Tests use fixtures (≥6 listings), not the CSV. `bin/ci` also runs seeds in the test env, so the seed file must work there too.

**Where the logic lives:** `Puzzle.for_date!`, `Game.start!(player_name:, date:)`, `Round#guess!(amount)` (does `with_lock`, checks for an existing guess, scores, saves, then `game.refresh_score!`), `Game.leaderboard(puzzle)`, and `GameSerializer` (a small Ruby class that builds the JSON). Controllers only parse params, call one model method, and render.

## 5. API (all JSON, under `/api`)

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `POST /api/games` | `{player_name}` | 201 + Game | 422 blank or too-long name |
| `GET /api/games/:token` | — | 200 + Game | 404 |
| `POST /api/games/:token/rounds/:position/guess` | `{guess}` | 200 + Game (the full updated game, so the frontend reducer just replaces its copy) | 404 if the token is unknown or position isn't 1–5; 422 if already guessed, not a whole number, ≤ 0, or > $100M |
| `GET /api/leaderboard` | — | 200 + today's top 10 completed games, by score desc then `completed_at` asc | — |

Errors always look like `{ "error": "message" }`. `ApplicationController` turns `RecordNotFound` into 404 and `RecordInvalid` or our `Round::AlreadyGuessed` into 422.

Payload shapes (these go into `frontend/src/types.ts` as the contract):

```jsonc
// Game
{
  "token": "pJ3k…24 chars", "player_name": "Max", "puzzle_date": "2026-10-20",
  "score": 920, "completed_at": null,
  "rounds": [
    { "position": 1,
      "listing": { "id": 7, "year": 1995, "make": "Suzuki", "model": "Jimny", "title": "…", "mileage": 76428,
                   "transmission": "manual", "body_style": "suv", "exterior_color": "…", "interior_color": "…",
                   "title_status": null, "highlights": "…", "image_urls": ["…"] },
      "result": { "guess": 9500, "points": 900, "sold_price": 10000, "pct_off": -5.0,
                  "sold_at": "…", "source": "Bring a Trailer", "source_url": "…" } },
    { "position": 2, "listing": { … }, "result": null }
  ]
}
// Leaderboard
{ "puzzle_date": "2026-10-20",
  "entries": [ { "rank": 1, "player_name": "Max", "score": 4210, "completed_at": "…", "you": false } ] }
```

Rounds don't have to be guessed in order. The UI goes in order, and guessing out of order gains nothing.

**Game tokens (D5).** Every game gets a random 24-character token from Rails' built-in `has_secure_token` (no new gem). The token is the **only** way to read or play a game, so it acts as the game's password. Integer IDs never appear in the API or URLs. Rounds are addressed by their 1–5 position within the token's game, so another game's round can't be reached. **The leaderboard never returns tokens.** It marks your row with `you: true` when you pass `?token=`. Tokens are about 140 bits of randomness (24 base58 characters), so they can't be guessed. The token lives in `localStorage` and in request URLs, so anyone who sees it can play that game (logged in known-limitations).

## 6. Frontend

One `useReducer` state machine in `App.tsx`. No router, no state library, Pico classless CSS.

```
boot ──(saved game for today?)──► resume ──► round | results
  └──────────────────────────────► start
start ──POST /games──► round(n) ──POST guess──► reveal(n) ──next──► round(n+1) … ──after 5──► results
```

### Why `useReducer`, not a router
- **What you're allowed to see depends on the game's state on the server, not on the URL.** A URL per screen creates states the server has to refuse: `/round/3` before round 2 is guessed, pressing Back to a round you've already guessed, a bookmark of yesterday's game. Each needs a guard and a redirect. With one reducer that works out the screen from the `Game` payload, invalid screens can't be reached at all.
- **All the transitions live in one pure function** (state, action) → state, which is easy to read and test.
- **The cost of a router:** a new package (`react-router` needs approval under README rule 5) or a hand-written history layer, for 4 screens with no deep links.
- **What a router would buy, and when to add one:** a working browser Back button, shareable URLs, and genuinely separate pages (a past-puzzles archive, a stats page). Wordle-style share links don't need one: read a query param at startup. Note a share link must **never** contain the game token, since the token lets anyone play the game. It would need a separate read-only ID.
- **Accepted gap:** browser Back leaves the app instead of going back a screen (known-limitations #10).

| Screen | Shows |
|---|---|
| **Start** | Title, today's date, name input (prefilled from `localStorage`), Play, today's leaderboard |
| **Round n/5** | Large photo + thumbnail strip, title, mileage, transmission, body, colors, title status (only if present), highlights; dollar input (strips `$`/`,`); Submit (disabled while sending, so a double-click can't send two guesses). Running score |
| **Reveal** | Sold price, your guess, % off ("13% high"), points, link to the auction (only shown now), Next / See results |
| **Results** | Total /5,000, per-round table, leaderboard with your row highlighted, "New cars tomorrow" |

Files: `api.ts` (all fetches; saves and loads `{date, token}` in `localStorage`), `types.ts` (contract), `App.tsx` (reducer + screen switch), `components/{StartScreen,RoundScreen,RevealScreen,ResultsScreen,Leaderboard,PhotoGallery}.tsx`, `format.ts` (the README's `Intl.NumberFormat` money formatter). Images load straight from the auction sites. Max confirmed this works on MaxFindsCars.com.

## 7. Work plan: lead + 2 lanes

**Foundation PR (lead, serial, ~20 min)**, which lanes build on:
- Migrations + `schema.rb`, models with validations/associations/`has_secure_token`, seeds, fixtures
- `Scoring` module + unit tests, `Listing#public_attributes`
- `frontend/src/types.ts` payload types (the API contract)
- Set `config.time_zone`, write `db/seeds.rb`

**Then in parallel (git worktrees, separate file ownership):**

| Lane | Owns | Done when |
|---|---|---|
| **A: Backend game API** | `app/models/{puzzle,game,round}.rb` logic, `app/serializers/`, `app/controllers/api/*`, `config/routes.rb`, `test/**` | Tests green for: price-leak test, double guess → 422, unknown token or bad position → 404, leaderboard never leaks tokens, invalid guesses, completion + score, daily puzzle is the same across games / changes the next day, leaderboard order |
| **B: Frontend** | `frontend/src/**` (except `types.ts`, which is frozen) | Lint + typecheck/build pass; codes against `types.ts`; the reducer works with a stubbed `api.ts` |

**Lead:** reviews each lane adversarially (runs the tests, plays the full loop in the browser with `npm run dev` against the local dev DB, tries curl attacks: double guess, leak check, bad input), then opens one PR per lane. Max merges.

Rough clock: design review 15 → foundation 20 → lanes 30 → review + integration 15 → your review 10.

## 8. Decisions (agreed with Max, 2026-10-20)

| # | Question | Decision |
|---|---|---|
| D1 | When does the day flip? | One clock: midnight **US Eastern** for everyone (known limitation) |
| D2 | Skip cars used on earlier days? | **Yes** |
| D3 | Finish a game after midnight? | **Yes**, counts on the day it started |
| D4 | Location | **Dropped.** `title_status` shown only when present |
| D5 | Game IDs | **Random tokens from the start** (`has_secure_token`) |
| D6 | Leaderboard scope | **Today only** (recommended; Max didn't object) |
| D7 | Fan-out timing | Foundation PR merged first, then lanes |
| D8 | Accounts | **Out of scope** |
| D9 | SQLite vs Postgres | SQLite for v1 (§3). Open for discussion; switching before the foundation PR merges is about a 10-minute change |
