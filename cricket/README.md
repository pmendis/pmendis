# Festival Cricket

A single-file cricket scoring app for the inter-department festival, published at
**https://pmendis.github.io/pmendis/cricket/** (separate from the sports app).

## What it does
- **Ball-by-ball scoring**: 0 · 1 · 2 · 3 · 4 · 6 · Wide · No-ball · Bye · Leg-bye · Wicket
  (bowled, caught, LBW, run out, stumped, hit wicket) · Undo · Swap strike · End innings.
  Strike rotation, over changes, all-out, target/chase and the result are automatic.
- **Live scorecards** for everyone: batting, bowling, extras, fall of wickets, over-by-over balls.
- **Points table**: Win 2 · Tie/No result 1 · Loss 0, ranked by points then **net run rate**
  (ICC method: runs scored per over faced minus runs conceded per over bowled; a side bowled out
  counts its full quota of overs). Only matches with stage "League" count.
- **Stats**: best batsmen (runs, average, strike rate, high score), best bowlers (wickets,
  economy, best figures), best fielders (catches, run-outs, stumpings) and player of the
  tournament (1 point per run, 20 per wicket, 10 per catch/run-out/stumping).
- **Teams & squads**: paste player names one per line.

## Who can edit
Anyone can view. Scoring and editing need a **username and password** that you create in Firebase:

1. Firebase console → **Authentication → Users → Add user**.
2. Email: `<username>@cricket.local` (e.g. `scorer1@cricket.local`), and a password.
3. The scorer signs in with just **scorer1** and the password ("Scorer sign in", top right).

Any Email/Password account in the project can score (anonymous visitors cannot).
Delete a user in Firebase to remove their access.

## Firebase setup
It uses the same Firebase project and config as the sports app, with its own collections
(`cr_settings`, `cr_teams`, `cr_players`, `cr_matches`). Publish the updated
`sports-festival/firestore.rules` (it now includes the cricket section) in
Firestore → Rules, with your owner email filled in.

## Scoring a match
1. **Teams**: add both teams with their players.
2. **Matches → + New match**: teams, date, venue, stage, overs, players per side.
3. Open the match: choose the toss result, openers and opening bowler, then score each ball.
4. At each over's end, pick the next bowler. After the 1st innings, start the 2nd.
5. The result is set automatically when the chase ends; **Undo** reopens if needed.
