# Inter-Department Sports Festival app

A single-file web app for the festival desk to manage **departments**, **sports/events** and **players**.

## Features
- **Departments** – name, short code (used in bib numbers, e.g. `CIV-001`), captain.
- **Sports** – team or individual, per-department quota, venue, date & time.
- **Players** – register with department, staff/student ID, gender, phone and events.
  Bib numbers are generated automatically. Quotas are enforced: a sport that is full
  for a department can't be ticked.
- **Overview** – totals and an entry board (departments × sports, with full / over-quota markers).
- Search and filter the roster, **export CSV** (useful for fixtures, ID cards, attendance sheets).
- Two-click delete; deleting a sport removes it from players' entries.

## Storage modes
The same file runs in two places:

| Where it runs | Data lives in | Who sees it |
|---|---|---|
| claude.ai Artifact (shared link) | Artifact shared database | Everyone the link is shared with, live |
| GitHub Pages / any static host / opened locally | Browser `localStorage` | Only that browser (use *Download backup* / *Restore backup*) |

## Hosting on GitHub Pages (free)
1. Merge this branch into `main`.
2. Repo **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. The workflow `.github/workflows/sports-festival-pages.yml` publishes to
   `https://<user>.github.io/<repo>/` on every push to `main` (or run it manually from the Actions tab).

## Run locally
Wrap `app.html` in a document as the workflow does, or simply open `app.html` in a browser.
