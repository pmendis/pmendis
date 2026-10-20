// Generates MapLibre style JSON for the Protomaps vector tiles.
//
// The app replaces {{BASE_URL}} with its gateway address at runtime, so the same
// style works from an emulator (10.0.2.2), a phone on the LAN, or production.
//
// Usage: npm install && npm run build
import { writeFileSync } from "node:fs";
import { layers, namedFlavor } from "@protomaps/basemaps";

const SOURCE = "protomaps";
// Fonts and sprites are hosted by Protomaps on GitHub Pages. Self-host before launch.
const ASSETS = "https://protomaps.github.io/basemaps-assets";

for (const flavor of ["light", "dark"]) {
  const style = {
    version: 8,
    name: `Lanka Maps ${flavor}`,
    glyphs: `${ASSETS}/fonts/{fontstack}/{range}.pbf`,
    sprite: `${ASSETS}/sprites/v4/${flavor}`,
    sources: {
      [SOURCE]: {
        type: "vector",
        tiles: ["{{BASE_URL}}/tiles/srilanka/{z}/{x}/{y}.mvt"],
        minzoom: 0,
        maxzoom: 15,
        bounds: [79.3, 5.7, 82.1, 10.1],
        attribution:
          '<a href="https://protomaps.com">Protomaps</a> © <a href="https://openstreetmap.org/copyright">OpenStreetMap contributors</a>',
      },
    },
    layers: layers(SOURCE, namedFlavor(flavor), { lang: "en" }),
  };
  writeFileSync(new URL(`./${flavor}.json`, import.meta.url), JSON.stringify(style) + "\n");
  console.log(`Wrote styles/${flavor}.json (${style.layers.length} layers)`);
}
