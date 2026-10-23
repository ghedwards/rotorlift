# AIRLIFT Android demo

## Install on a phone

Open https://ghedwards.github.io/rotorlift/download/ on the phone and tap **Download for Android**. The APK is hosted directly on GitHub Pages and requires no GitHub login.

This is a native, offline ARM64 Android demo. Download `airlift-demo.apk` to the phone, open it, and allow that browser/file manager to install the APK when Android asks. The app stays in landscape; either sideways orientation works. Google Play Protect may ask to scan an app installed outside the Play Store.

Only install the file shared by the developer. You can turn the install permission back off afterwards. No Google Play account is needed for this APK playtest.

This build is for direct testing, not a Google Play upload. Each workflow run uses a fresh, temporary debug signing key. To install a later demo, you may need to uninstall the previous one, which also removes local progress and assist settings. The separate `com.ghedwards.airlift.demo` package keeps these disposable demos separate from a future store app. We will establish a backed-up upload key and Play App Signing for the store version.

## What to test

- Defaults: altitude hold on, ground tether on, auto-hoist off. Change each independently in Menu → Settings.
- Start at the base and take off. Move the left joystick diagonally to steer and climb together; try small and full movements.
- Complete a winch rescue, check the route/tension panel switch, and return to base.
- Land at the field pad, send the rescuer, help the survivor, and return together.
- Keep one finger on the joystick while another taps the round right-hand winch button. The rescue cross deploys/cancels the winch and handles ground rescues; the up arrow hoists the stretcher.
- Open the top-bar menu and check Resume, Settings, Flight manual and Fullscreen. Opening it pauses flight and releases both thumbs. Android Back closes menus or pauses/resumes the game.
- Switch to another app and back: the game should remain paused until resumed.
- Report phone model, Android version, the action that failed, and whether the problem is layout, input or frame rate.

Native export removes the browser runtime and browser chrome, but layout and frame-rate quality still need physical-device testing. The display is landscape with immersive mode; native phones use the translucent joystick and round winch overlays even on high-resolution displays.

## Build another demo

Run **Build Android demo** from this repository's GitHub Actions tab. It verifies the Godot 4.7.2 downloads, runs the game checks, exports a debug-signed ARM64 APK, verifies its signature, and uploads `airlift-android-demo`. Download and unzip that artifact to get the APK, checksum and manifest information. Artifacts expire after 30 days and require GitHub access; share the extracted APK directly with friends.

For a local build, install the matching Godot Android export templates, Java and Android SDK, set the Java/Android paths in Godot Editor Settings, then run:

```sh
mkdir -p godot/builds/android
godot --headless --path godot --editor --import --quit
godot --headless --path godot --export-debug 'Android Demo' builds/android/airlift-demo.apk
```

Never commit signing keystores/passwords. Build outputs and Android secrets are ignored by Git.

## Move to Google Play internal testing

1. Create a Google Play Console developer account (US$25 one-time registration fee), complete Google's identity/device verification and required account steps.
2. Create the AIRLIFT app record. Choose a permanent application ID before the first store upload.
3. Create and securely back up an upload key; enroll in Play App Signing. Configure a separate release export using Gradle and Android App Bundle (`.aab`) format. The demo APK is not store-ready.
4. Complete the required app details, testing release information and declarations based on the app's actual behavior. Do not claim a completed data/privacy review from this demo configuration alone.
5. Upload the signed AAB to **Internal testing**, add testers (up to 100), and share the opt-in link. This track is suitable for the first friend demos.
6. Test on real phones before expanding distribution. Google's production-access testing requirements for new personal accounts are a later step, separate from this internal demo.

Account creation, payment, identity verification, signing ownership and the final store submission remain account-holder steps. No Play Store release has been submitted by this workflow.

References:
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- https://support.google.com/googleplay/android-developer/answer/6112435
- https://support.google.com/googleplay/android-developer/answer/9845334

## Update the Pages download

Replace `distribution/android/airlift-demo.apk`, `SHA256SUMS.txt` and `INSTALL.md` with the verified demo build. Update `build-info.json` with the exact version, source commit, byte count and SHA-256. The Pages packager rejects an APK whose size or checksum differs. Push to `main` to publish `/download/`; this copy stays available after the temporary Actions artifact expires. The browser-only ZIP excludes the native download.
