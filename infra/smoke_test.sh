#!/usr/bin/env bash
# Checks that every service behind the gateway answers.
# Usage: infra/smoke_test.sh [gateway-url]   (default http://localhost:8080)
set -uo pipefail

BASE="${1:-http://localhost:8080}"
failures=0

check() {
  local name="$1" url="$2" expect="$3"
  local body
  if body="$(curl -fsS --max-time 20 "$url" 2>&1)" && grep -q -- "$expect" <<<"$body"; then
    echo "ok    $name"
  else
    echo "FAIL  $name"
    echo "      $url"
    echo "      ${body:0:200}"
    failures=$((failures + 1))
  fi
}

# Colombo Fort → Kandy by car.
route='{"locations":[{"lat":6.9344,"lon":79.8428},{"lat":7.2906,"lon":80.6337}],"costing":"auto","directions_options":{"units":"kilometers"}}'

check "gateway"        "$BASE/health" "ok"
check "map style"      "$BASE/styles/light.json" '"version":8'
check "routing status" "$BASE/valhalla/status" '"version"'
check "route"          "$BASE/valhalla/route?json=$(jq -rn --arg r "$route" '$r|@uri')" '"maneuvers"'
check "search"         "$BASE/geocode/search?q=Kandy&format=jsonv2&countrycodes=lk&limit=1" '"lat"'
check "reverse"        "$BASE/geocode/reverse?lat=6.9344&lon=79.8428&format=jsonv2" '"display_name"'

# A Colombo tile at zoom 10 (binary, so only check the HTTP status).
if curl -fsS --max-time 20 -o /dev/null "$BASE/tiles/srilanka/10/739/492.mvt"; then
  echo "ok    vector tile"
else
  echo "FAIL  vector tile ($BASE/tiles/srilanka/10/739/492.mvt)"
  failures=$((failures + 1))
fi

if ((failures)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All services are up."
