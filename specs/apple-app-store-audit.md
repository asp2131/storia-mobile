# Apple App Store Audit — Storia Flutter

Audit date: 2 March 2026
App: **Storia** — an illustrated storybook reader with narration and ambient soundscapes.
Bundle ID: `com.storia.storiaFlutter`

---

## Executive summary

Storia is a well-structured Flutter app with clean architecture (Riverpod + GoRouter + Supabase) and solid basics (HTTPS-only, no hardcoded secrets, proper `.env` handling). However, several areas need attention before an App Store submission will succeed. The items below are grouped by severity.

---

## BLOCKERS — Will cause App Store rejection

### 1. Missing Privacy Policy

Apple requires a publicly accessible privacy policy URL for **every** app. No privacy policy exists in the repo or is linked from the app.

**What to do:**
- Write a privacy policy covering: what data you collect (book content fetched from Supabase, cached images), what you don't collect (no PII, no accounts, no tracking), and how third-party services are used (Supabase, Google Fonts).
- Host it at a stable URL (e.g. `https://storia.com/privacy`).
- Add the URL in App Store Connect under "App Information > Privacy Policy URL".
- Also link it from within the app (see item 10).

### 2. App Store Privacy Nutrition Labels

Apple requires you to declare your data practices in App Store Connect. Since Storia:
- Does **not** collect any personal data
- Does **not** track users across apps
- Does **not** use analytics or advertising SDKs
- Uses only anonymous Supabase reads

...you should be able to declare **"Data Not Collected"** — but you must still fill out the form. Google Fonts fetches may count as "Data Used to Track You" if Google collects IP addresses; review Google Fonts' data practices.

### 3. Missing App Icon Asset

`pubspec.yaml` references `assets/icon/icon.png` for `flutter_launcher_icons`, but no `assets/icon/` directory exists in the repo. Without a proper app icon, the build will fail or Apple will reject the submission.

**What to do:**
- Create a 1024x1024 PNG app icon (no alpha channel for iOS).
- Place it at `assets/icon/icon.png`.
- Run `dart run flutter_launcher_icons` to generate all platform-specific sizes.
- Verify the generated icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`.

### 4. No Crash Reporting or Global Error Handling

Apple expects apps to be stable. Without crash reporting, you'll be flying blind after release. Your own checklist (`specs/release-publishing-checklist.md` line 99) already flags this.

**What to do:**
- Add Firebase Crashlytics or Sentry.
- Wrap `runApp()` in `runZonedGuarded` and set `FlutterError.onError` to forward errors to the crash reporter.
- Example structure for `main.dart`:

```dart
void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // ... existing init ...
    FlutterError.onError = (details) {
      // Forward to Crashlytics/Sentry
    };
    runApp(const ProviderScope(child: StoriaApp()));
  }, (error, stack) {
    // Forward to Crashlytics/Sentry
  });
}
```

### 5. COPPA / Kids Category Considerations

Storia appears to be a children's storybook app. If you intend to target children under 13, or list in the **Kids** category:
- You **must** comply with COPPA and Apple's Kids category guidelines.
- You **cannot** include third-party analytics, advertising, or data collection.
- You **must** declare the target age range in App Store Connect.
- Google Fonts loads fonts from the network at runtime, which may violate Kids category rules (third-party network calls). Consider bundling fonts as assets instead.

If you do **not** target the Kids category, you still must set an appropriate age rating in App Store Connect.

### 6. Export Compliance (HTTPS / Encryption)

Supabase communication uses HTTPS (TLS), which counts as encryption under US export regulations. When uploading to App Store Connect, you'll be asked about encryption.

**What to do:**
- In `Info.plist`, add:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
- This is appropriate because your use of HTTPS/TLS for standard networking is exempt. Adding this key also skips the manual export compliance question on every build upload.

---

## HIGH PRIORITY — Likely to cause rejection or poor review experience

### 7. No Accessibility Support

Apple reviewers test with VoiceOver. The app has zero `Semantics` widgets, `semanticsLabel` properties, or `ExcludeSemantics` wrappers. Interactive elements (book cards, playback controls, volume sliders, search field) will be inaccessible to screen readers.

**What to do:**
- Add `Semantics` wrappers to book cards in `library_screen.dart` (e.g. `Semantics(label: 'Book: ${book.title} by ${book.author}', button: true, ...)`).
- Add `semanticsLabel` to icon buttons in the reader (play/pause, next/previous, audio settings).
- Add `Semantics` to volume sliders with value descriptions.
- Test with VoiceOver on a real iOS device.

### 8. Display Name and Bundle Name

- `CFBundleDisplayName` is `Storia Flutter` — the "Flutter" suffix looks unprofessional on the home screen.
- `CFBundleName` is `storia_flutter` — this shows in system-level UI (settings, notifications).

**What to do:**
- Change `CFBundleDisplayName` to `Storia` (or your preferred brand name).
- Change `CFBundleName` to `Storia`.

### 9. No Dark Mode Support

Apple's Human Interface Guidelines strongly recommend supporting dark mode. The app only defines a light theme in `app_theme.dart`. Reviewers may flag this, and users on iOS dark mode will have a jarring experience switching into the app.

**What to do:**
- Create a `buildDarkAppTheme()` function in `app_theme.dart`.
- Update `app.dart` to pass both themes:
```dart
MaterialApp.router(
  theme: buildAppTheme(),
  darkTheme: buildDarkAppTheme(),
  themeMode: ThemeMode.system,
  // ...
)
```

### 10. No Settings / About Screen with Legal Links

Apple expects apps to provide a way for users to access the privacy policy and terms of service from within the app. There is currently no settings screen at all.

**What to do:**
- Add a simple settings/about screen accessible from the library (e.g. a gear icon in the app bar).
- Include links to: Privacy Policy, Terms of Service, app version, and a support/contact email.

### 11. Error States Lack Retry Actions

Both `_ErrorState` (library) and `_ReaderErrorState` (reader) display errors but offer no retry button. If a user has a momentary network issue, they're stuck.

**What to do:**
- Add a "Try Again" button to both error states that triggers a data refresh.

---

## MEDIUM PRIORITY — Won't block review but should be addressed

### 12. Unused Dependencies

Two dependencies are declared in `pubspec.yaml` but never imported in `lib/`:
- `flutter_secure_storage`
- `connectivity_plus`

These add to binary size and may trigger unnecessary App Store privacy questions (e.g. `flutter_secure_storage` uses the iOS Keychain).

**What to do:**
- Remove them from `pubspec.yaml` if not needed.

### 13. Google Fonts Network Dependency

`google_fonts` fetches fonts over the network at runtime. This means:
- First launch without connectivity will use fallback fonts.
- It makes an external network call on every fresh install.
- It may conflict with Kids category requirements (see item 5).

**What to do:**
- Bundle the Inter font as a local asset and use `GoogleFonts.interTextTheme()` with the `fontFamily` parameter pointing to the bundled font, or switch to a local `TextTheme` using `pubspec.yaml` font declarations.

### 14. No Meaningful Tests

The only test is a `2 + 2 = 4` sanity check. Apple won't reject you for this, but it increases the risk of shipping bugs that *will* get you rejected.

**What to do:**
- Add widget tests for `LibraryScreen` (loading, data, error states).
- Add widget tests for `ReaderScreen` (page navigation, audio controls).
- Add unit tests for `BookRepository` and data models.

### 15. Background Audio Without `audio_service`

`Info.plist` declares `UIBackgroundModes: audio`, and the app uses `just_audio` — but there is no `audio_service` or `just_audio_background` package. This means:
- Background playback may work inconsistently.
- Lock screen / Control Center media controls won't appear.
- Apple may question why you declare background audio if it doesn't work properly from the lock screen.

**What to do:**
- Add `audio_service` (or `just_audio_background`) to properly support background audio with lock-screen controls and now-playing metadata.
- Or, if background audio isn't a core feature, remove the `UIBackgroundModes` entry from `Info.plist`.

### 16. No CI/CD or Automated Builds

No GitHub Actions, Fastlane, or other automation. This isn't an App Store requirement, but it dramatically reduces the risk of shipping broken builds.

**What to do:**
- Set up a basic GitHub Actions workflow for `flutter analyze`, `flutter test`, and `flutter build ipa --no-codesign`.
- Consider Fastlane for automated App Store uploads.

### 17. iPad Support

`Info.plist` declares iPad orientations (`UISupportedInterfaceOrientations~ipad`), which means Apple will expect the app to work well on iPad. If it doesn't, they'll reject it.

**What to do:**
- Test the app on iPad simulators (various sizes).
- Ensure the library grid and reader scale properly on larger screens.
- If iPad isn't ready, add `UIRequiresFullScreen` or restrict to iPhone-only in Xcode.

---

## LOW PRIORITY — Nice to have for a polished submission

### 18. No Onboarding / First-Run Experience

The app drops users directly into the library with no introduction. A brief onboarding (even a single screen) explaining that Storia is a storybook reader with narration would improve the reviewer's first impression and user retention.

### 19. No Cupertino Widgets on iOS

The app uses Material widgets exclusively. While this works, using `CupertinoNavigationBar`, `CupertinoAlertDialog`, etc. on iOS would feel more native and align with Apple HIG. This is not a rejection risk but contributes to a polished experience.

### 20. Launch Screen Branding

The current iOS launch screen is a plain white background with a generic `LaunchImage`. A branded splash (logo + background color) would make a better first impression.

### 21. Localization

All strings are hardcoded in English. If you plan to launch in non-English markets, set up Flutter's `l10n` system with `.arb` files. Even for English-only, extracting strings makes future localization trivial.

### 22. Deep Linking

No universal links or custom URL schemes are configured. If you want to support links like `https://storia.com/book/123` opening directly in the app, you'll need to set up associated domains in `Info.plist` and the Apple Developer portal.

### 23. Support URL

App Store Connect requires a support URL. Ensure you have a support page or at minimum a support email address ready.

---

## App Store Connect Checklist

These are non-code items you'll need to prepare:

| Item | Status |
|------|--------|
| Apple Developer account ($99/year) | Verify active |
| App name reserved in App Store Connect | TODO |
| Bundle ID registered in Apple Developer portal | `com.storia.storiaFlutter` |
| App Store screenshots (6.7", 6.5", 5.5" iPhone; iPad if supported) | TODO |
| App Store description and keywords | TODO |
| App Store promotional text (170 chars) | TODO |
| Privacy policy URL | TODO |
| Support URL | TODO |
| Age rating questionnaire | TODO |
| App category (e.g. Books, Education) | TODO |
| Pricing (Free / Paid / Freemium) | TODO |
| App review notes (explain how to test the app) | TODO |
| Export compliance | Add `ITSAppUsesNonExemptEncryption` to Info.plist |

---

## Recommended Implementation Order

1. **App icon** — blocks building entirely
2. **Privacy policy** — blocks submission
3. **`ITSAppUsesNonExemptEncryption` in Info.plist** — quick win, avoids manual step on every upload
4. **Fix display name** — quick win (`Storia` instead of `Storia Flutter`)
5. **Crash reporting + global error handling** — safety net before release
6. **Accessibility basics** — high rejection risk
7. **Error state retry buttons** — improves reviewer experience
8. **Settings screen with legal links** — reviewer expectation
9. **Dark mode** — reviewer expectation on iOS
10. **Background audio (audio_service)** — consistency with declared capability
11. **Bundle fonts locally** — reliability + COPPA safety
12. **Remove unused dependencies** — cleaner binary
13. **Tests** — confidence for future updates
14. **iPad testing / restriction** — declared support must work
15. **CI/CD** — sustainability
