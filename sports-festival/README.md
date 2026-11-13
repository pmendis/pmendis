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
| Where it runs | Data lives in |
|---|---|
| claude.ai Artifact (shared link) | Artifact shared database, live for everyone with access |
| GitHub Pages / any static host / opened locally | Browser `localStorage` (use *Download backup* / *Restore backup*) |

## Hosting on GitHub Pages (free)
1. Merge this branch into `main`.
2. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. `.github/workflows/sports-festival-pages.yml` publishes to `https://<user>.github.io/<repo>/`
   on every push to `main` (or run it from the Actions tab). Until both steps are done the URL shows a 404.
