# Storia Mobile

Flutter mobile app for Storia Kids.

## Setup

1. Install Flutter and iOS tooling.
2. Run:

```bash
flutter pub get
```

3. Start the app:

```bash
flutter run
```

## iOS Sign In with Apple

The iPhone flow uses native Apple Sign In with Supabase as the backend session issuer.

Required Apple-side setup:

- App ID: `com.storia.storiaFlutter`
- Team ID: `FKB97T38LY`
- Capability enabled on the App ID: `Sign in with Apple`
- App Store provisioning profile: `Storia App Store Profile`
- Distribution certificate: `Apple Distribution`

The app entitlement lives in [ios/Runner/Runner.entitlements](/Users/akinpound/Documents/experiments/storia-mobile/ios/Runner/Runner.entitlements).

## iOS App Store Build

Archive with Flutter:

```bash
flutter build ipa --export-method app-store
```

If Flutter export fails with a provisioning/profile mismatch around `Sign in with Apple`, use the working two-step path below.

### 1. Build the archive

```bash
flutter build ipa --export-method app-store
```

If archive succeeds but IPA export fails, keep the generated archive at:

`build/ios/archive/Runner.xcarchive`

### 2. Export manually with Xcode

Create an export options plist that pins the bundle ID to the correct provisioning profile:

```bash
printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'  <key>method</key>' \
'  <string>app-store-connect</string>' \
'  <key>signingStyle</key>' \
'  <string>manual</string>' \
'  <key>teamID</key>' \
'  <string>FKB97T38LY</string>' \
'  <key>signingCertificate</key>' \
'  <string>Apple Distribution</string>' \
'  <key>provisioningProfiles</key>' \
'  <dict>' \
'    <key>com.storia.storiaFlutter</key>' \
'    <string>Storia App Store Profile</string>' \
'  </dict>' \
'</dict>' \
'</plist>' > /tmp/storia-export-options.plist
```

Then export:

```bash
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/ipa-manual \
  -exportOptionsPlist /tmp/storia-export-options.plist
```

Successful output lands in:

`build/ios/ipa-manual`

## Why this is needed

`flutter build ipa` can successfully create the archive but still fail during `exportArchive` when Xcode picks the wrong signing context for a capability-enabled app. In this project, the failure showed up after native `Sign in with Apple` was added on iPhone.

The manual `xcodebuild -exportArchive` step works because it explicitly maps:

- `com.storia.storiaFlutter` -> `Storia App Store Profile`

That removes ambiguity during export.
