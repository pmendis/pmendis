# Free Navigation App — Build Plan

A Google Maps–style app (map browsing, search, turn-by-turn navigation) built entirely on
free and open-source data and software, so it can be offered free of charge without
per-request API bills.

---

## 1. Short answer: is it feasible?

**Yes, as long as the scope stays realistic.** Every core building block exists as mature open
source:

| Capability | Google Maps uses | Free/open equivalent |
|---|---|---|
| Map data | Proprietary | **OpenStreetMap (OSM)**, under the ODbL license |
| Map rendering | Proprietary vector tiles | **MapLibre GL** (web, Android, iOS) + **OpenMapTiles / Protomaps** vector tiles |
| Search / geocoding | Places API | **Photon** or **Nominatim** (OSM-based) |
| Routing | Directions API | **Valhalla** (recommended), OSRM, or GraphHopper |
| Turn-by-turn guidance | Proprietary SDK | **MapLibre Navigation** / **Ferrostar** (open-source nav SDK built for Valhalla) |
| Live traffic | Crowdsourced Android data | Not freely available. See §8 |
| Street View, reviews, business photos | Proprietary | Out of scope (Mapillary and Panoramax are partial alternatives) |

What you **can** match: maps, address/POI search, driving/walking/cycling routes, voice
turn-by-turn, rerouting, offline maps.
What you **can't** easily match: real-time traffic, rich business data (hours, reviews,
photos), and Street View.

"Free" means free to users and free of licensing fees. **Hosting still costs money.** The
cost of routing, geocoding and tile servers grows with coverage area and traffic (§9).

---

## 2. Product scope

### MVP (v1)
1. Interactive vector map: pan, zoom, rotate, light/dark styles
2. Show the user's current location (GPS)
3. Search for addresses and places with autocomplete
4. Route from A to B for **car, walking and bicycle**, with ETA and distance
5. Show alternative routes
6. Turn-by-turn navigation: voice prompts, lane hints, automatic rerouting when off-route
7. Saved places (Home, Work, favourites), stored on the device
8. Recent searches

### v2
- Offline maps: download a region's tiles, routing graph and search index
- Public transit routing (GTFS feeds + OpenTripPlanner / MOTIS)
- Multi-stop routes, avoid tolls/highways/ferries
- Speed limits and speed-camera warnings (from OSM tags)
- Share ETA / live location
- "Report an issue" feature that sends edits upstream to OSM

### v3 (optional)
- Crowdsourced traffic from opted-in, anonymized user speeds
- Incident reports (accident, police, road closure), Waze-style
- CarPlay / Android Auto
- Accounts and cloud sync for saved places

---

## 3. Architecture

```
┌──────────────────────────── Client apps ────────────────────────────┐
│  Mobile: Flutter or React Native  (or native Kotlin / Swift)        │
│   • MapLibre Native  – map rendering                                │
│   • Ferrostar        – navigation UI, off-route detection, voice    │
│   • Device TTS       – spoken instructions                          │
│   • Local DB         – saved places, offline packs                  │
│  Web: React + MapLibre GL JS                                        │
└───────────────┬───────────────────────────┬─────────────────────────┘
                │ HTTPS                     │
        ┌───────▼────────┐         ┌────────▼─────────┐
        │  API gateway   │         │  CDN (tiles,     │
        │  (Caddy/Nginx) │         │  styles, fonts)  │
        │  rate limiting │         └────────▲─────────┘
        └──┬───────┬─────┘                  │
           │       │                        │
   ┌───────▼──┐ ┌──▼────────┐      ┌────────┴─────────┐
   │ Valhalla │ │  Photon   │      │ PMTiles file in  │
   │ routing  │ │ geocoding │      │ object storage   │
   └────▲─────┘ └────▲──────┘      └────────▲─────────┘
        │            │                      │
   ┌────┴────────────┴──────────────────────┴─────────┐
   │         Data pipeline (weekly batch job)          │
   │  OSM .pbf extract (Geofabrik) → build routing     │
   │  tiles, search index and vector map tiles         │
   └───────────────────────────────────────────────────┘
```

### Key technology choices

| Layer | Choice | Why |
|---|---|---|
| Mobile framework | **Flutter** (`maplibre_gl`) or React Native (`@maplibre/maplibre-react-native`) | One codebase for Android and iOS. Go native Kotlin/Swift if navigation polish matters most, since Ferrostar's best bindings are native. |
| Map rendering | **MapLibre** | Open-source fork of Mapbox GL. GPU vector rendering, custom styles. |
| Tiles | **Protomaps (PMTiles)** | A single static file served from S3/R2 plus a CDN. No tile server to run, and very cheap. |
| Map style | Protomaps basemap styles or OpenMapTiles styles | Ready-made light/dark themes. |
| Routing | **Valhalla** | Car, bike and foot profiles; alternatives; turn-lane data; multi-language instructions; time-dependent costing; small memory footprint; works offline on-device. |
| Geocoding | **Photon** (autocomplete) + **Nominatim** (reverse lookup) | Photon is built for search-as-you-type. |
| Navigation SDK | **Ferrostar** | Built for Valhalla. Handles route following, snapping, off-route detection and spoken instructions. |
| Backend glue | Small Go or Node service | Auth (later), rate limiting, API keys for your own clients, caching. |
| Infra | Docker Compose to start, Kubernetes later | Valhalla and Photon both ship Docker images. |

---

## 4. Data pipeline

1. **Download** an OSM extract from Geofabrik (for example, one country) or the full planet
   (~80 GB `.pbf`).
2. **Routing:** `valhalla_build_tiles`, which builds the routing graph. Optionally add elevation
   data (for cycling) and admin/timezone data.
3. **Search:** import into Nominatim, then export a Photon index, or download a prebuilt Photon
   dump.
4. **Map tiles:** use **Planetiler** to turn the `.pbf` into a `.pmtiles` file (the whole planet
   takes about 1–3 hours on a large machine).
5. **Publish:** upload the PMTiles file to object storage and do a rolling restart of Valhalla
   and Photon with the new data.
6. **Schedule:** run weekly with GitHub Actions or a cron job on a build box.

**Start with a single country or region.** That keeps build times in minutes and servers small.

---

## 5. Navigation logic (the hard part)

Most of the polish in a navigation app lives here:

- **Map matching / snapping:** snap noisy GPS positions to the route line.
- **Off-route detection:** reroute when the user is more than about 30–50 m off the route for
  several seconds.
- **Instruction timing:** announce turns based on distance and speed ("In 500 m…", "Now turn
  left").
- **Background location:** keep navigating with the screen off. This needs a foreground service on
  Android and background location mode on iOS.
- **Battery:** lower the GPS rate and render less when not navigating.
- **Day/night style switching**, plus auto-zoom and tilt based on speed.

Ferrostar covers most of the first three. The rest is app work.

---

## 6. Milestones (single developer or small team)

| Phase | Duration | Deliverables |
|---|---|---|
| **0. Spike** | 1 week | Docker Compose running Valhalla + Photon + a PMTiles basemap for one region. A web page with a MapLibre map that draws a route between two clicks. |
| **1. Core map app** | 2–3 weeks | Mobile app skeleton, map, current location, search with autocomplete, place details sheet. |
| **2. Routing** | 2 weeks | A→B routes, mode switcher (car/walk/bike), alternatives, route summary, ETA. |
| **3. Turn-by-turn** | 3–4 weeks | Ferrostar integration, voice guidance, rerouting, background navigation, arrival handling. |
| **4. Hardening** | 2 weeks | Data pipeline automation, monitoring, rate limiting, crash reporting, OSM attribution screen, privacy policy. |
| **5. Beta release** | 1–2 weeks | TestFlight / Play internal testing, feedback, store listing. |
| **6. v2 features** | ongoing | Offline regions, transit, multi-stop routes. |

**About 3 months to a solid regional beta.** Planet-scale coverage and transit add more time.

---

## 7. Suggested repository layout

```
/apps
  /mobile          Flutter or React Native app
  /web             React + MapLibre GL JS
/services
  /gateway         API gateway: rate limits, caching, API keys
/infra
  docker-compose.yml   valhalla, photon, nominatim, caddy
  /k8s                 (later)
/pipeline
  build_routing.sh     valhalla_build_tiles
  build_tiles.sh       planetiler → .pmtiles
  build_search.sh      photon index
  .github/workflows/data-refresh.yml
/styles            map style JSON, sprites, fonts
/docs
```

---

## 8. Traffic and ETA accuracy

Free, global real-time traffic data does not exist. Options, from simplest to hardest:

1. **No traffic (MVP).** Use OSM speed limits and road classes. ETAs will be optimistic in cities.
2. **Historical speed profiles.** Valhalla supports time-of-day speed data if you can obtain it
   (some cities and governments publish open data).
3. **Crowdsourcing.** Collect anonymized, opt-in GPS speeds from your own users and aggregate them
   per road segment. This only becomes useful once you have a meaningful user base.
4. **Paid feed.** Buy traffic data from TomTom or HERE. This stops being free.

---

## 9. Hosting cost estimate (rough)

| Coverage | Valhalla RAM/disk | Photon disk | Tiles | Approx. monthly |
|---|---|---|---|---|
| One small country | 2–4 GB / 5 GB | ~5 GB | ~1 GB PMTiles | **$10–30** (one VPS + R2) |
| Large country / continent | 16–32 GB / 50 GB | ~50 GB | ~30 GB | **$80–200** |
| Whole planet | 64 GB+ / 150 GB+ | ~100 GB | ~120 GB | **$300–600+** |

Tiles served from Cloudflare R2 have no egress fees, so map display stays cheap even with many
users. Routing and search are the costs that grow with traffic, so cache aggressively and
rate-limit.

---

## 10. Legal and compliance checklist

- **OSM attribution is required:** show "© OpenStreetMap contributors" on the map. Derived databases
  fall under the ODbL share-alike terms.
- **Do not use Google Maps tiles or data.** Google's terms forbid scraping or mixing its data in.
- **Do not use the public `tile.openstreetmap.org` or public Nominatim servers in production.** Their
  usage policies forbid heavy use, so self-host.
- **Location privacy:** process location on the device where possible, keep server logs short-lived,
  and don't store trip histories without consent. GDPR applies if you have EU users.
- **App store rules:** justify background location use for navigation. Show a driving-safety
  disclaimer.

---

## 11. Risks and mitigations

| Risk | Mitigation |
|---|---|
| OSM data gaps in some regions | Pick a launch region with good OSM coverage. Add an in-app "report an issue" that links to OSM edits. |
| Navigation UX feels weaker than Google | Use Ferrostar rather than building navigation from scratch. Test early on real drives. |
| Server costs grow with users | PMTiles on a CDN, route/search caching, offline-first design that pushes work to the device. |
| No traffic → poor ETAs | Set expectations in the UI. Plan crowdsourced speeds for v3. |
| iOS/Android background limits | Use native navigation services. Test on low-end Android devices. |

---

## 12. Decisions and status

- **Launch region:** Sri Lanka
- **Mobile stack:** Flutter (Android, iOS and web from one codebase)
- **Phase 0 (proof of concept):** done. See [README.md](README.md). Differences from the plan
  above:
  - Search uses **Nominatim** for now. Photon has no prebuilt Sri Lanka index, so it will be
    added later, built from the Nominatim database, for better search-as-you-type.
  - Tiles come from cutting Sri Lanka out of the daily Protomaps planet build
    (`pipeline/fetch_tiles.sh`) instead of running Planetiler.

**Next:** Phase 1–2 polish (place details sheet, saved places, recent searches), then phase 3
turn-by-turn navigation with Ferrostar.
