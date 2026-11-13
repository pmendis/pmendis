#!/usr/bin/env bash
# Weekly data refresh: newest Sri Lanka map tiles and routing graph, so fixes
# made in OpenStreetMap (including the app's problem reports) reach the app.
# Search (Nominatim) updates itself daily from Geofabrik's replication feed.
#
# Schedule with cron, e.g. every Monday at 03:00:
#   0 3 * * 1  /path/to/repo/pipeline/refresh_data.sh >> /var/log/lanka-maps-refresh.log 2>&1
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE=(docker compose -f "$ROOT/infra/docker-compose.yml")
TILES="$ROOT/infra/data/tiles"

echo "== $(date -u +%FT%TZ) refreshing map data"

# 1. Tiles: build into a temporary name, then swap, so the server never
#    serves a half-written file.
NAME=srilanka.new "$ROOT/pipeline/fetch_tiles.sh"
mv -f "$TILES/srilanka.new.pmtiles" "$TILES/srilanka.pmtiles"
"${COMPOSE[@]}" restart tiles

# 2. Routing: valhalla-scripted re-downloads the extract and rebuilds the
#    graph when it starts with an empty data directory. Routing is down for
#    the rebuild (about 5–10 minutes for Sri Lanka).
"${COMPOSE[@]}" stop valhalla
# The files belong to the container's user, so delete them from inside one.
"${COMPOSE[@]}" run --rm --no-deps --entrypoint sh valhalla -c 'rm -rf /custom_files/*'
"${COMPOSE[@]}" up -d valhalla

echo "Waiting for the routing graph to rebuild…"
for _ in $(seq 1 90); do
  if "${COMPOSE[@]}" exec -T valhalla curl -fsS http://localhost:8002/status >/dev/null 2>&1; then
    echo "== routing is back up"
    "$ROOT/infra/smoke_test.sh" || true
    exit 0
  fi
  sleep 20
done
echo "Routing did not come back within 30 minutes; check: docker compose logs valhalla" >&2
exit 1
