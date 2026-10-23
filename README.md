# AIRLIFT — Search & Rescue

A Godot 4.7.2 / GDScript helicopter rescue game with three extended missions, momentum flight, wind, timed winch rescues and playable ground rescues.

## Play with friends

Browser release: **https://ghedwards.github.io/rotorlift/** (available once the Pages deployment succeeds).

Open it on a computer or a phone held in landscape. Computers use WASD/arrows and Space; phones use the on-screen controls. The info icon opens the flight manual; the cog contains sound, mission selection and independent difficulty assists. A browser supporting WebGL 2 and WebAssembly is required. Real iPhone/Android device testing is still needed; desktop and emulated landscape-phone checks have passed.

## Run locally

Import `godot/project.godot` into **Godot 4.7.2 standard** and press F5. No .NET is needed. See [the game guide](godot/README.md) for mechanics and headless tests.

## Publish updates

The [Pages workflow](.github/workflows/pages.yml) builds and tests the Godot game on pushes to `main`, or through **Actions → Publish AIRLIFT → Run workflow**. It pins the engine version, verifies release checksums, exports without threading, bundles license notices and deploys only the web files. See [sharing and deployment](godot/SHARING.md).

## Artwork and animation

Static artwork and animated character atlases are editable SVGs in `godot/Assets/Art`. UI icons are bundled from Lucide with their source revision and license in `godot/Assets/Icons`. The gameplay geometry, rotors, rope and effects remain dynamic.

The earlier React/Canvas prototype remains in `src/` and `airlift.html`; its [original instructions](docs/html-prototype.md) are retained for reference. The Pages workflow deploys the Godot edition.

Native Android demo: [download and installation](https://ghedwards.github.io/rotorlift/download/).
