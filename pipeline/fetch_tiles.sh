#!/usr/bin/env bash
# Cut a Sri Lanka vector tile file out of the daily Protomaps planet build.
#
# Only the tiles inside the bounding box are downloaded (HTTP range requests),
# so this takes a few minutes and produces a file of roughly 100–200 MB.
#
# Usage: pipeline/fetch_tiles.sh [build-date YYYYMMDD]
set -euo pipefail

BBOX="${BBOX:-79.3,5.7,82.1,10.1}"   # min_lon,min_lat,max_lon,max_lat (Sri Lanka + margin)
MAXZOOM="${MAXZOOM:-15}"
NAME="${NAME:-srilanka}"
PMTILES_IMAGE="protomaps/go-pmtiles:v1.31.2"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/infra/data/tiles"
mkdir -p "$OUT_DIR"

# Find the newest available daily build, starting from today.
build="${1:-}"
if [[ -z "$build" ]]; then
  for days_ago in $(seq 0 14); do
    candidate="$(date -u -d "-$days_ago day" +%Y%m%d)"
    if curl -fsI "https://build.protomaps.com/$candidate.pmtiles" >/dev/null; then
      build="$candidate"
      break
    fi
  done
fi
if [[ -z "$build" ]]; then
  echo "Could not find a Protomaps build from the last 14 days." >&2
  exit 1
fi

src="https://build.protomaps.com/$build.pmtiles"
echo "Extracting $NAME (bbox $BBOX, maxzoom $MAXZOOM) from $src"

if command -v pmtiles >/dev/null; then
  pmtiles extract "$src" "$OUT_DIR/$NAME.pmtiles" --bbox="$BBOX" --maxzoom="$MAXZOOM"
else
  docker run --rm -v "$OUT_DIR:/data" "$PMTILES_IMAGE" \
    extract "$src" "/data/$NAME.pmtiles" --bbox="$BBOX" --maxzoom="$MAXZOOM"
fi

echo "Wrote $OUT_DIR/$NAME.pmtiles"
