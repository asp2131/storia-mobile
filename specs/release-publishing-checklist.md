# Flutter App Publishing Checklist

Love it — let’s ship 🚀

## 1) Final pre-release checks

- Update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

- Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

- Test on:
  - At least 1 real iPhone + 1 real Android
  - Small + large screen
  - Dark mode (if supported)
  - Offline / poor network behavior

---

## 2) iOS release prep (App Store)

- In Xcode (`ios/Runner.xcworkspace`):
  - Set correct **Bundle Identifier**
  - Set **Team** / signing
  - Ensure app icon + launch assets are valid
- In `Info.plist`, ensure required privacy permission strings exist (e.g. `NSCameraUsageDescription`, etc.)
- Build release IPA:

```bash
flutter build ipa
```

- Upload via:
  - Xcode Organizer, or
  - Transporter app
- In App Store Connect:
  - Create app record
  - Add screenshots, description, keywords, privacy, age rating
  - Configure pricing + availability
  - Submit for review

---

## 3) Android release prep (Play Store)

- Create upload keystore (if not done already):

```bash
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

- Create `android/key.properties` (do not commit this file):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

- Configure release signing in `android/app/build.gradle.kts`:
  - Load `key.properties`
  - Create `signingConfigs.release`
  - Set `buildTypes.release.signingConfig = signingConfigs.release`
  - **Do not** use `signingConfigs.debug` for release

- Build app bundle:

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

- Upload `build/app/outputs/bundle/release/app-release.aab` to Play Console
- Fill out:
  - App content (privacy policy, data safety, ads)
  - Store listing assets
  - Target audience, content rating
- Roll out to internal testing first, then production

---

## 4) Must-have before pressing submit

- Crash reporting enabled (Firebase Crashlytics/Sentry)
- Analytics events for key flows
- Backend production environment confirmed
- Terms/Privacy Policy links live
- Support email configured
- Release notes ready
