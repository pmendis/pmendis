# House Sports Desk

A single-file web app for one house/department at an inter-department sports festival:
manage **your players**, the **sports you have entered**, and your **games** (fixtures, line-ups, results).

## Features
- **House** – name, short code (used in player numbers, e.g. `CIV-01`), captain.
- **Players** – name, staff/student ID (duplicates rejected), gender, phone, sports they play.
  Squad numbers are assigned automatically; a sport whose squad is full can't be ticked.
- **Sports** – team or individual, squad size limit, notes.
- **Games** – sport, round, opponent, date/time, venue, line-up picked from that sport's squad,
  result (won / draw / lost) and score.
- **Overview** – next games, squad fill per sport, and the won–drawn–lost record.
- Search/filter players and export CSV. Two-click delete.

## Storage modes
The app picks a mode automatically:

| Where it runs | Data lives in | Who can see / edit |
|---|---|---|
| GitHub Pages with Firebase configured | Firebase Firestore (free tier) | Anyone with the link can view; only the signed-in organiser can edit |
| claude.ai Artifact | Artifact shared database | People the artifact is shared with |
| Anywhere else (no Firebase config) | Browser `localStorage` | That browser only (use *Download backup* / *Restore backup*) |

## Setting up Firebase (one-time, about 10 minutes)
1. Go to https://console.firebase.google.com and **Create a project** (any name, Analytics off).
2. **Build → Firestore Database → Create database** → *Start in production mode* → pick a location → Enable.
3. In Firestore, open the **Rules** tab, replace everything with the contents of `firestore.rules`, and **Publish**.
4. **Build → Authentication → Get started → Email/Password → Enable → Save.**
   Then **Users → Add user**: your email and a password. This is the only account that can edit.
5. **Project settings (gear icon) → Your apps → Web (`</>`)** → register the app (no hosting) →
   copy the `firebaseConfig` values (`apiKey`, `authDomain`, `projectId`, `appId`).
6. Put the config in the site, either way:
   - edit `sports-festival/firebase-config.js` and commit, **or**
   - repo **Settings → Secrets and variables → Actions → Variables → New repository variable**,
     name `FIREBASE_CONFIG`, value the JSON object, e.g.
     `{"apiKey":"AIza...","authDomain":"myhouse.firebaseapp.com","projectId":"myhouse","appId":"1:123:web:abc"}`
7. Re-run the Pages workflow (Actions tab → Deploy Sports Festival app → Run workflow).
8. Open the site, tap **Sign in to edit**, and start adding your house.

The config values are not secret: access is controlled by the Firestore rules.
If an open-in-browser warning about an unauthorised domain appears on sign-in, add
`<user>.github.io` under **Authentication → Settings → Authorized domains**.

## Hosting on GitHub Pages (free)
`.github/workflows/sports-festival-pages.yml` publishes to `https://<user>.github.io/<repo>/`
on every push to `main`. It enables Pages itself on first run; if the `github-pages`
environment restricts deployment branches, allow `main` under Settings → Environments.
