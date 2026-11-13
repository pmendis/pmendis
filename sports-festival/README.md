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
   Note the project ID in the address bar (`/project/<PROJECT_ID>/`); the links below use it.
2. Firestore: `https://console.firebase.google.com/project/PROJECT_ID/firestore` →
   **Create database** → *production mode* → pick a location → Enable.
3. Open the **Rules** tab there, replace everything with the contents of `firestore.rules`,
   change `owner@example.com` to the Google account you will sign in with, and **Publish**.
4. Authentication: `https://console.firebase.google.com/project/PROJECT_ID/authentication/providers` →
   **Get started** → enable **Email/Password** → Save. Then **Users → Add user** for yourself
   (the owner email from the rules) and for each helper who should be able to edit.
5. Still in Authentication → **Settings → Authorized domains** → add `<user>.github.io`.
6. Config: `https://console.firebase.google.com/project/PROJECT_ID/settings/general` → scroll to
   **Your apps** → **`</>`** (Web) → register → copy `apiKey`, `authDomain`, `projectId`, `appId`.
7. Put the config in the site, either way:
   - edit `sports-festival/firebase-config.js` and commit, **or**
   - repo **Settings → Secrets and variables → Actions → Variables → New repository variable**,
     name `FIREBASE_CONFIG`, value the JSON object, e.g.
     `{"apiKey":"AIza...","authDomain":"myhouse.firebaseapp.com","projectId":"myhouse","appId":"1:123:web:abc"}`
8. Re-run the Pages workflow (Actions tab → Deploy Sports Festival app → Run workflow).
9. Open the site, tap **Sign in to edit**, enter your email and password, and start adding your house.

The config values are not secret: the Firestore rules decide who can write.

## Approving other editors
Anyone can view without signing in. Only accounts you create under Authentication → Users can
sign in at all. When one of them signs in and isn't an editor yet,
the app records an access request and shows them "access requested". You (or any approved editor)
see the request under **Overview → Editor access** and tap **Approve** or **Decline**. Approved
people can edit until you **Remove** them. The owner named in the rules can always edit.

## Hosting on GitHub Pages (free)
`.github/workflows/sports-festival-pages.yml` publishes to `https://<user>.github.io/<repo>/`
on every push to `main`. It enables Pages itself on first run; if the `github-pages`
environment restricts deployment branches, allow `main` under Settings → Environments.
