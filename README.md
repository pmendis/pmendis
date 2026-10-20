# Lanka Maps

A free, Google Maps–style map and navigation app for Sri Lanka, built entirely on
OpenStreetMap data and open-source software. See [PLAN.md](PLAN.md) for the full plan.

This is the **phase 0 proof of concept**: a self-hosted backend plus a Flutter app
(Android, iOS and web) that can browse the map, search for places, and plan
driving, cycling and walking routes with alternatives and turn-by-turn steps.

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

Requirements: Docker with Compose, about 8 GB RAM and 20 GB disk free, and Flutter 3.38+.

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

- **Tiles:** re-run `pipeline/fetch_tiles.sh`, then `docker compose restart tiles`.
- **Routing:** set `force_rebuild: "True"` on the valhalla service for one start,
  or delete `infra/data/valhalla`, then restart it.
- **Search:** Nominatim is configured with Geofabrik's Sri Lanka replication feed.
  See the [mediagis/nominatim docs](https://github.com/mediagis/nominatim-docker)
  for update modes.

## Proof-of-concept limits

- Search uses **Nominatim**. Photon (search-as-you-type) has no ready-made Sri Lanka
  index, so it is left for later, built from this Nominatim database.
- Map fonts and icons load from Protomaps' public GitHub Pages. Self-host them
  before launch.
- No live traffic, voice guidance or rerouting yet. Those are phases 2–3 in the plan.
- The gateway has no rate limiting or TLS. Put it behind HTTPS before exposing it
  publicly.

Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), ODbL.
