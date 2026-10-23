/**
 * Builds a single portable file: airlift.html
 *
 * The normal `npm run build` emits dist/index.html plus a dist/images folder.
 * That is ideal for hosting, but it needs a server. This script takes the built
 * HTML and replaces every backdrop reference with a compact base64 JPEG, so the
 * whole game becomes one file you can double-click, email, or drop on any host.
 *
 * Usage:  npm run build && node scripts/inline-assets.mjs
 */
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const dist = join(root, "dist");
const out = join(root, "airlift.html");
const quality = 72;
const width = 1900;

if (!existsSync(join(dist, "index.html"))) execSync("npm run build", { cwd: root, stdio: "inherit" });

const temporary = join(root, ".inline-cache");
mkdirSync(temporary, { recursive: true });

/** Re-encode a backdrop PNG as a smaller JPEG and return it as a data URI. */
function inlineImage(name) {
  const source = join(root, "public", "images", `${name}.png`);
  const target = join(temporary, `${name}.jpg`);
  execSync(`convert "${source}" -resize ${width}x -quality ${quality} -strip "${target}"`, { stdio: "inherit" });
  return `data:image/jpeg;base64,${readFileSync(target).toString("base64")}`;
}

let html = readFileSync(join(dist, "index.html"), "utf8");
let total = 0;

for (const name of ["alpine-backdrop", "coastal-backdrop", "wildfire-backdrop"]) {
  const dataUri = inlineImage(name);
  const before = html;
  html = html.split(`/images/${name}.png`).join(dataUri);
  if (before === html) throw new Error(`No reference to /images/${name}.png in dist/index.html`);
  total += dataUri.length;
}

const favicon = readFileSync(join(root, "public", "favicon.svg"), "utf8");
html = html.split("/favicon.svg").join(`data:image/svg+xml,${encodeURIComponent(favicon.trim())}`);

// External fonts still load when online; the CSS already falls back gracefully offline.
writeFileSync(out, html);
execSync(`rm -rf "${temporary}"`);

const kb = (n) => `${Math.round(n / 1024)} KB`;
console.log(`\nairlift.html  ${kb(html.length)}  (inlined artwork: ${kb(total)})`);
console.log("Open it directly in a browser, or upload it anywhere static.\n");
