# Rotorlift store listing kit

## Identity and links

- Store name: **Rotorlift**
- Android package / iOS bundle ID: **dev.edification.rotorlift**
- Current uploaded version: **0.0.1**
- Browser game: https://ghedwards.github.io/rotorlift/
- Support URL (after this Pages deployment): https://ghedwards.github.io/rotorlift/support/
- Privacy URL (after this Pages deployment): https://ghedwards.github.io/rotorlift/privacy/
- Feedback: https://github.com/ghedwards/rotorlift/issues/new?template=playtest.yml
- Planned domain: https://rotorlift.edification.dev/ (DNS not configured yet)

The old AIRLIFT Android app is a separate app. Upload Rotorlift bundles only to the new Rotorlift record. The sideload APK on Pages currently installs under its existing AIRLIFT Demo identity; the refreshed icon is prepared for future native builds and does not modify already uploaded binaries.

## Copy to paste

### Google Play short description (maximum 80 characters)

Pilot rescue missions. Brave the wind and bring everyone home.

### App Store subtitle (maximum 30 characters)

Helicopter rescue missions

### Full description / TestFlight beta description

Take the controls of a rescue helicopter and bring every survivor home.

Fly through mountain ridges, an exposed coastline and a wildfire valley. Manage momentum, changing winds and obstacles as you position your helicopter for each rescue.

Lower a rescue specialist and stretcher, keep the hook steady while the patient is secured, then winch the crew back aboard. At marked field landing zones, land the helicopter and control the rescuer on foot to help a survivor and escort them back.

Features:
- Three rescue missions: Pine Ridge, Storm Coast and Ember Valley.
- Momentum-based flight with changing wind conditions.
- Timed winch rescues and playable ground rescues.
- Hazards including trees, cliffs, powerlines, birds and fire.
- Touch joystick and rescue controls, designed for landscape play.
- Separate altitude hold, ground tether and auto-hoist assists.
- Local mission progress and assist settings.

Rotorlift is currently an early playtest. Controls, difficulty and presentation are still being refined, and your feedback helps shape the next build.

### App Store keywords (maximum 100 characters)

helicopter,rescue,flight,pilot,winch,stretcher,mountain,coast,fire,simulation

### What to Test

Please test in landscape on a real phone:
1. Take off from base. Try small joystick movements, diagonal flight and braking in the opposite direction.
2. Complete a winch rescue. Keep the hook in the survivor circle, check the countdown resets when interrupted, then hoist and return home.
3. Land at a field landing zone, send the rescuer, help the survivor and escort them back to the helicopter.
4. Try altitude hold, ground tether and auto-hoist separately in Menu → Settings.
5. Check later-level wind, bird visibility, obstacle collisions and landing speed.
6. Pause, switch apps and return; check that flight remains paused until resumed.

Please report your phone model, OS version, app build, mission and the steps that caused a problem. Screenshots or a short recording are useful. TestFlight feedback is welcome, or use the public GitHub issue form.

### Beta review notes

No account, sign-in or invitation code is required inside the game. The game runs offline.

Hold the device in landscape. Use the left joystick to steer and climb. Tap the circular rescue button on the right to operate the winch. Keep the hook within the survivor circle until loading completes, then tap again to hoist. Return rescued survivors to the base helipad. The top-right menu opens Settings and the Flight manual.

Default assists: altitude hold on, ground tether on, auto-hoist off. These can be changed independently in Settings. There are no in-app purchases in this build.

### Initial release notes

Initial Rotorlift playtest with three rescue missions, wind-driven flight, timed winch rescues, ground rescues and configurable flight assists.

## Screenshots and icon assets

Generated files live in the ignored folder `godot/builds/store-listing/`:

- `google-play/`: four 1920 × 1080 landscape PNG screenshots.
- `app-store-iphone/`: four 2868 × 1320 landscape PNG screenshots.
- `google-play-feature-1024x500.png`: feature graphic.
- `google-play-icon-512.png`: opaque Play listing icon.
- `app-store-icon-1024.png`: opaque App Store icon source for the next native build.

Capture order: winch rescue, Storm Coast, ground rescue, wildfire flight. These are staged gameplay states rendered by the actual native Godot game, not painted mockups. They use phone-layout controls at the requested store dimensions. They are not screenshots taken on a physical iPhone; check a real device before final store submission. No iPad screenshots are supplied because the iOS preset targets iPhone.

Regenerate with a real renderer (do not use `--headless`):

```sh
godot --path godot --windowed --resolution 960x540 --script Tools/capture_store_screenshots.gd
```

Upload Android screenshots and the feature graphic in the Rotorlift app's main store listing. Apple screenshots belong to the App Store version's screenshot section, not the TestFlight What to Test field. TestFlight beta distribution does not require a full public App Store screenshot listing.

## Fields the account owner still supplies

- Public support/feedback email for the stores and TestFlight.
- Beta review contact details (and phone number if requested).
- Content/age-rating answers and store privacy/data-safety declarations based on the shipped build.
- Final category, pricing and release decisions.

The privacy page documents current code behavior: no account, ad/analytics SDK, in-app purchase or developer-operated network endpoint is present in the game scripts; progress/assists are stored locally. Browser hosting, optional public GitHub reports and store/TestFlight diagnostics have their own service policies. Review the page and store questionnaires together; this kit does not submit answers to either console.

## New icon rollout

The updated SVG icon is configured for the next Android/iOS export and the browser favicon. The already submitted TestFlight build keeps its original icon until a new build is uploaded. Increase native build numbers for the next upload. The account owner can replace Play's listing icon independently of uploading a binary.

## References

- Apple screenshot sizes: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Google Play assets: https://support.google.com/googleplay/android-developer/answer/9866151
- TestFlight test information: https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/
