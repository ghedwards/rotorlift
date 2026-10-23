# Rotorlift local iOS export

Godot preset: **iOS TestFlight**. Bundle ID: `dev.edification.rotorlift`.
Apple team: `EA3D6755HZ`. Marketing version: `0.0.1`. Build number: `1`.
The project is landscape and this preset targets iPhone.

## Requirements

Install full Xcode, finish its first-launch setup with iOS platform support, and sign into the Apple Developer account in Xcode Settings → Accounts. The standalone Command Line Tools package does not contain the iPhone SDK. Xcode must have access to team `EA3D6755HZ`.

The matching Godot 4.7.2 iOS template is cached locally at `builds/cache/ios.zip` and referenced by the preset. On another machine, install the matching export templates and clear the Custom Template paths, or place the matching iOS template at that cache path.

## Build locally through Godot

```sh
python3 godot/Tools/export_ios_local.py --godot /absolute/path/to/Godot
```

The helper runs Godot's project export, archives with Apple's build tools, then signs the IPA for App Store Connect. Output: `godot/builds/ios/testflight/Rotorlift.ipa`. Logs are under `godot/builds/ios/`.

The team uses Xcode's cloud-managed distribution signing during export. Godot's direct signed archive path requests a development device profile first, which fails if the team has no registered iPhone. Keep **Application → Export Project Only** enabled for this helper: the intermediate archive is unsigned, then the final IPA is distribution-signed. Signing credentials remain with Xcode/Apple and must not be committed.

The helper scopes `DEVELOPER_DIR` to `/Applications/Xcode.app/Contents/Developer`, without changing the global developer setting. It uses Apple's system PATH during packaging to avoid an incompatible Homebrew rsync.

## Upload a new build

Increase **Application → Version** (build number) for every subsequent upload. Keep the marketing version at `0.0.1` until a new visible version is intended. Keep the bundle ID unchanged for this app.

```sh
python3 godot/Tools/export_ios_local.py --godot /absolute/path/to/Godot --upload
```

After upload, wait for App Store Connect to process the build. In Rotorlift → TestFlight, resolve any processing/export-compliance questions, add the build to an external tester group, supply beta review information and submit for review. External testers can install after Apple approves it. Uploading alone does not make the build available to friends.
