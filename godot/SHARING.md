# Sharing AIRLIFT

## First release: one browser link

The intended URL is https://ghedwards.github.io/rotorlift/. Once the workflow succeeds, friends can use that link on computers and landscape phones without installing Godot or downloading a desktop executable. Progress and assists are saved separately in each browser/device.

The export uses the Compatibility renderer and **single-threaded** WebAssembly. It needs WebGL 2, WebAssembly and an HTTP(S) server; `file://` is unsupported. It does not require COOP/COEP headers, which makes it suitable for GitHub Pages.

### GitHub Pages setup

1. In repository **Settings → Pages**, select **GitHub Actions** as the source.
2. Push the game and `.github/workflows/pages.yml` to `main` (or run **Publish AIRLIFT** manually).
3. Wait for both `build` and `deploy` to succeed, then open the workflow's deployed URL.

The workflow downloads the official Godot 4.7.2 editor and export templates, verifies their SHA-512 checksums, runs scene/rescue/animation/all-mission checks and exports the browser build. It uploads only `godot/builds/site`, not the repository or development cache. The public repository's main branch is the release source; future game changes pushed there will publish automatically after passing checks.

### Local release packaging

Install the matching Godot export templates, then from the repository root:

```sh
mkdir -p godot/builds/web
godot --headless --path godot --editor --import --quit
godot --headless --path godot --export-release Web builds/web/index.html
python3 godot/Tools/package_web.py --output godot/builds/site-preview
python3 -m http.server 8080 --directory godot/builds/site-preview
```

Choose a fresh output directory for each packaging run. The script also produces a sibling `.zip`, with `index.html` at its root, for manual static hosting or an HTML5 upload to itch.io. It includes engine, font and icon license notices. Build output is ignored by Git; CI rebuilds it from source.

### Friend playtest checklist

- Desktop: Chrome/Edge/Firefox and Safari; keyboard movement, opposite-direction braking, Space interactions, sound and fullscreen.
- Android Chrome and iPhone/iPad Safari: rotate to landscape, simultaneous steering/climb touches, winch interaction, pause and settings. Fullscreen availability varies by browser.
- Complete a timed winch rescue and a landing rescue, then return to base.
- Refresh and confirm completed missions/assists persist. Private-browsing storage may not persist.
- Report phone model, browser, mission and what happened, ideally with a short screen recording.

Automated mobile viewport checks are not a substitute for physical phone performance and touch testing. Portrait layout is not yet a supported play mode. The footer's radio bubble can scroll when narrow.

## Native Android demos

The browser build remains available for desktop testing. For phone playtests, use the native Android demo workflow and installation instructions in [ANDROID-DEMO.md](ANDROID-DEMO.md). Google Play internal testing follows developer-account setup and a separate signed AAB release.

## Other native apps

A browser link is the first distribution path. Desktop exports can be provided as downloads later, but macOS distribution benefits from signing/notarization. Android APK testing needs an Android export setup and signing key; Google Play and iOS/TestFlight add their own account/signing/review work. None of those accounts or signing keys are needed for the Pages browser playtest.

References:
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
- https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages
- https://itch.io/docs/creators/html5
