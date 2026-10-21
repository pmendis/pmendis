# Lanka Maps

A free, Google Maps–style map and navigation app for Sri Lanka, built entirely on
OpenStreetMap data and open-source software. See [PLAN.md](PLAN.md) for the full plan.

A self-hosted backend plus a Flutter app (Android, iOS and web) with:
- map browsing and place search
- saved places and recent searches
- driving, cycling and walking directions
- voice turn-by-turn navigation with rerouting
- a hand-off to Google Maps
- in-app reporting of map problems to OpenStreetMap

See [apps/mobile/README.md](apps/mobile/README.md) for the app's features.

```
apps/mobile/      Flutter app
infra/            docker compose backend: Valhalla, Nominatim, PMTiles server, Caddy gateway
pipeline/         data scripts (vector tiles for Sri Lanka)
styles/           MapLibre map styles (generated from @protomaps/basemaps)
```

| Piece | Software | Gateway path |
|---|---|---|
| Routing + directions | Valhalla 3.9 | `/valhalla/*` |
| Search + reverse geocoding | Nominatim 5.3 | `/geocode/*` |
| Vector map tiles | Protomaps PMTiles + `pmtiles serve` | `/tiles/*` |
| Map style | Protomaps basemap (light, dark) | `/styles/*` |

## Quick start

Requirements: Docker with Compose, about 8 GB RAM and 20 GB disk free, and Flutter 3.44+.

```bash
# 1. Vector tiles for Sri Lanka (a few minutes, ~100–200 MB)
pipeline/fetch_tiles.sh

# 2. Backend. The first start downloads the Sri Lanka OSM extract and builds
#    the routing graph (~5–10 min) and the search database (~20–40 min).
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml up -d
docker compose -f infra/docker-compose.yml logs -f nominatim   # watch the import

# 3. Check that everything answers
infra/smoke_test.sh

# 4. App
cd apps/mobile
flutter pub get
flutter run            # Android emulator, or: flutter run -d chrome
```

On a physical phone, pass your computer's LAN address:
`flutter run --dart-define=API_BASE_URL=http://<your-ip>:8080`.

## Updating the data

- **Search** updates itself daily from Geofabrik's Sri Lanka replication feed.
- **Tiles and routing:** run `pipeline/refresh_data.sh` weekly, for example from cron:
  ```
  0 3 * * 1  /path/to/repo/pipeline/refresh_data.sh >> /var/log/lanka-maps-refresh.log 2>&1
  ```
  It swaps in new tiles without downtime, then rebuilds the routing graph.
  Routing is unavailable for about 5–10 minutes during the rebuild.

Edits made in OpenStreetMap, including fixes for the app's problem reports,
reach the app through these refreshes.

## Production

```bash
cd infra
SITE_ADDRESS=maps.example.lk docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

Point the domain's DNS at the server first. Caddy then gets and renews an HTTPS
certificate automatically. Build the app with
`--dart-define=API_BASE_URL=https://maps.example.lk`.

## Known limits

- **No live traffic.** Arrival times assume free-flowing roads. The app offers
  "Open in Google Maps" for traffic-aware trips. See PLAN.md §8 for options.
- **Search uses Nominatim.** Photon (better search-as-you-type) has no
  ready-made Sri Lanka index. It can be added later, built from this Nominatim database.
- **Map fonts and icons** load from Protomaps' public GitHub Pages. Self-host
  them for full independence.
- **The gateway has no rate limiting.** Add it (for example a Caddy rate-limit
  plugin or a CDN in front) before a public launch.
- **No offline maps or public transit yet.** Both are v2 items in the plan.
- **The app icon and store listing** still need designing before release.

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL.
