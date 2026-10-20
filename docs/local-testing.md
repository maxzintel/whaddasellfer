# Local testing

Tools for replaying the daily game on your machine. They work in development and test only: the reset route isn't drawn in production, and the model methods refuse to run there.

## In the browser (`npm run dev`)

A dashed **Dev** toolbar sits under every screen. It is only in development builds; `npm run build` leaves it out.

| Button | What it does |
|---|---|
| **New player** | Forgets this browser's game and name, then reloads to the start screen. **Same 5 cars**, and the leaderboard is kept. Works mid-game too. |
| **Reset today** | Asks first, then deletes today's puzzle, games and rounds on the server (`POST /api/dev/reset_today`), and reloads. The next game picks **new cars**, and the leaderboard starts empty. |

## In the terminal

```bash
npm run reset        # same as "Reset today": delete today's puzzle + games
npm run reset:all    # delete every puzzle and game (listings stay); every car becomes "unused" again
```

After `npm run reset` or `npm run reset:all`, reload the browser. A saved game that no longer exists sends you to the start screen.

## Notes
- "New cars" after a reset are a fresh random pick from the unused pool. Cars from the deleted puzzle count as unused again, so one could come back (about a 1-in-8 chance on a fresh database that at least one does).
- To test the midnight rollover, use `travel_to` in a test. The app's clock is `Time.zone.today` (US Eastern).
