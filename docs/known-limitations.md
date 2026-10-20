# Known limitations

Gaps we've accepted on purpose for v1, each with the reason and what fixing it would take. Add to this list as we find more.

| # | Limitation | Why we accept it | Fix later |
|---|---|---|---|
| 1 | **The day flips at midnight US Eastern for everyone.** A player in London gets new cars at 5am, and one in California at 9pm. | One server-side clock means everyone worldwide plays the same puzzle, and players can't reach other days by changing their device clock. | Per-timezone puzzles (like Wordle). That means trusting the client's date, with checks to stop players reaching other days. |
| 2 | **"One game per day" is only a soft limit.** Clearing `localStorage` or using a new name lets someone replay with the answers already known. | No accounts in v1. | Accounts (or a signed device cookie), plus one game per player per puzzle. |
| 3 | **The game token is a bearer secret.** Whoever has the token (from `localStorage` or the URL) can play that game. | It's random (~140 bits), so it can't be guessed. That's far better than sequential IDs, and fine without accounts. | Tie games to accounts or an HttpOnly cookie. |
| 4 | **Image URLs reveal the auction site and upload month** (e.g. `bringatrailer.com/wp-content/uploads/2025/11/...`). A curious player could look up the sale. | Serving images through our own server costs bandwidth and time. The title is searchable anyway. | Serve images through our own image proxy, or a cache with neutral URLs. |
| 5 | **Images load straight from the auction sites.** If BaT or C&B change their URLs or block outside sites from showing their images, photos break. | Works today on MaxFindsCars.com. | Cache copies of the images in our own storage. |
| 6 | **A game finished after midnight counts on the day it started.** | Kinder to late-night players, and there's no way to cheat with it. | n/a |
| 7 | **Cars repeat after 40 days** (200 listings / 5 per day). Once every listing has been used, picks come from the full pool again. | Seed data is a fixed snapshot. | Import new sold listings regularly. |
| 8 | **Scoring is harsher on high guesses than low ones.** Guessing 1.5× the price scores 0, but the mirror-image low guess (⅔×) still scores 333. | It's the v1 formula from the README. | Score on the log of the guess/price ratio, which treats high and low misses equally. |
| 9 | **Single-server SQLite.** The app can't run more than one server or on hosts that wipe the disk. | See the database decision in DESIGN.md §3. | Move to Postgres when we deploy beyond one server. |
| 10 | **Browser Back leaves the app** instead of going back one screen. | No router: screens come from game state, so a URL can't point at a screen you aren't allowed to see (DESIGN.md §6). | Use `history.pushState` for each screen, or add a router once there are real separate pages. |
