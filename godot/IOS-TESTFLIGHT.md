# Rotorlift local iOS export

Godot preset: **iOS TestFlight**. Bundle ID: `dev.edification.rotorlift`.
Apple team: `EA3D6755HZ`. Marketing version: `0.0.1`. Build number: `1`.
The project is landscape and this preset targets iPhone.

## Current local export

The preset initially enables **Application → Export Project Only**, so the native project can be generated before Apple signing is configured. Output goes into the ignored `builds/ios/` folder. This is not an installable or TestFlight-uploadable IPA.

The matching Godot 4.7.2 iOS template is cached locally at `builds/cache/ios.zip` and referenced by this preset. On another machine, install the matching export templates and clear the Custom Template paths, or place the matching iOS template at that cache path.

## Complete a signed export through Godot

1. Install full Xcode from the Mac App Store. Launch it once, accept its license, and install iOS platform support. The standalone Command Line Tools package does not contain the iPhone SDK.
2. Sign in to the Apple Developer account in Xcode Settings → Accounts so automatic signing can access the team. Ensure its Apple Distribution identity and App Store provisioning are available. Signing credentials belong in Keychain, not Git.
3. Ensure `xcode-select -p` points to the full Xcode developer directory. If needed, run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` after installation.
4. Open this project in Godot → Project → Export → iOS TestFlight. Disable **Export Project Only**, confirm the signing/team options and export without debug enabled. Godot invokes Apple's build tools to archive and export `builds/ios/Rotorlift.ipa`.
5. Upload the resulting IPA with Apple's Transporter or authenticated App Store Connect tooling. In App Store Connect, resolve any processing/compliance questions, then add the build to the TestFlight tester group. External testers require Apple's beta review.

Increase **Application → Version** (build number) for every subsequent upload. Keep the marketing version at `0.0.1` until a new visible version is intended. Never change the bundle ID for this registered app.
