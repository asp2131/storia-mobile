# Plan: App Store & Google Play Submission Readiness

## Task Description
Audit the Storia mobile app (Expo/React Native book reader) for App Store and Google Play submission readiness, fix all blocking issues, create required assets and metadata, configure build signing, and prepare production builds for both platforms.

## Objective
Get the Storia app fully ready for submission to both the Apple App Store and Google Play Store, including all required code fixes, build configuration, store assets, metadata, legal documents, and production builds.

## Problem Statement
Storia is a functional Expo SDK 54 / React Native 0.81.5 book reader app with library browsing, full reader with audio playback, and gesture navigation. However, it has never been submitted to either app store. Key gaps include:

- **No EAS Build configuration** (`eas.json` missing)
- **No Apple Developer Team ID** configured
- **Android release keystore not generated** (uses debug keystore for release)
- **`SYSTEM_ALERT_WINDOW` permission** in Android manifest (will flag on Google Play)
- **Downloads tab is a stub** (empty state only — potential rejection risk)
- **AuthProvider not wired** into root layout
- **Tab bar uses emoji icons** instead of proper icon library
- **Environment variables hardcoded to localhost** (`lib/api.ts` defaults to `localhost:3000`)
- **No privacy policy, terms of service, or store listing metadata**
- **No App Store screenshots or Google Play feature graphic**
- **No EAS credentials or signing configured**
- **Age rating questionnaire not completed** on either platform
- **Data safety / privacy nutrition labels not prepared**
- **No account deletion flow** (required by both stores if app has accounts)

## Solution Approach
Work in phases: (1) Fix code blockers that would cause rejection, (2) Configure build & signing infrastructure, (3) Prepare store assets & metadata, (4) Build & validate production binaries, (5) Final validation.

## Relevant Files
Use these files to complete the task:

- `app.json` — Expo config; needs EAS project ID, version bumps, plugin adjustments
- `package.json` — Scripts, dependencies; needs EAS CLI scripts, proper icon library
- `app/(tabs)/_layout.tsx` — Tab bar layout with emoji icons; needs proper icon components
- `app/(tabs)/downloads.tsx` — Stub downloads tab; needs minimum viable implementation or removal
- `app/_layout.tsx` — Root layout; AuthProvider needs to be wired in
- `lib/api.ts` — API client; defaults to localhost; needs production URL
- `lib/supabase.ts` — Uses `NEXT_PUBLIC_SUPABASE_URL` env var naming (Next.js convention, should be `EXPO_PUBLIC_*`)
- `ios/Storia/Info.plist` — iOS permissions and ATS config
- `ios/Storia/Storia.entitlements` — Empty; may need push notification or other entitlements
- `ios/Storia/PrivacyInfo.xcprivacy` — Privacy manifest; needs review for accuracy
- `android/app/src/main/AndroidManifest.xml` — Android permissions; `SYSTEM_ALERT_WINDOW` must be removed for release
- `android/app/build.gradle` — Android build config; release signing points to debug keystore
- `assets/icon.png` — App icon (verify 1024x1024)
- `assets/splash-icon.png` — Splash screen image
- `assets/adaptive-icon.png` — Android adaptive icon foreground

### New Files
- `eas.json` — EAS Build configuration for development, preview, and production profiles
- `privacy-policy.md` or hosted URL — Privacy policy document
- `terms-of-service.md` or hosted URL — Terms of service document
- Store screenshots (generated from device/simulator captures)
- Google Play feature graphic (1024x500)

## Implementation Phases

### Phase 1: Foundation — Fix Code Blockers
Fix issues that would cause immediate rejection or broken functionality in production:
1. Remove `SYSTEM_ALERT_WINDOW` from Android manifest
2. Remove/clean deprecated `WRITE_EXTERNAL_STORAGE` permission
3. Wire AuthProvider into root layout
4. Fix environment variable naming (`NEXT_PUBLIC_*` → `EXPO_PUBLIC_*`)
5. Ensure API URL defaults to production (not localhost)
6. Replace emoji tab icons with `@expo/vector-icons`
7. Either implement minimum viable downloads tab or remove the tab entirely
8. Add account deletion capability (required by both stores)

### Phase 2: Core Implementation — Build & Signing Infrastructure
1. Install and configure EAS CLI (`npx eas-cli`)
2. Create `eas.json` with development, preview, and production build profiles
3. Set Apple Developer Team ID
4. Generate Android release upload keystore
5. Configure Android Gradle for release signing with the new keystore
6. Enroll in Google Play App Signing
7. Run `eas build` for both platforms to verify builds succeed
8. Set up EAS Submit configuration for automated store uploads

### Phase 3: Store Assets & Metadata Preparation
1. Verify app icon meets both platform specs (1024x1024 iOS, 512x512 Google Play)
2. Capture screenshots on required device sizes (iPhone 6.9", iPad 12.9" if supporting tablet, Android phone)
3. Create Google Play feature graphic (1024x500)
4. Draft app name, subtitle, description, keywords for both stores
5. Draft and host privacy policy
6. Draft terms of service
7. Prepare demo account credentials for App Review
8. Complete Apple privacy nutrition labels mapping
9. Complete Google Play data safety section mapping

### Phase 4: Integration & Polish — Production Builds & Validation
1. Run production EAS builds for iOS and Android
2. Upload iOS build to TestFlight; run internal test
3. Upload Android AAB to Google Play internal testing track
4. Complete age rating questionnaires on both platforms
5. Fill in all store listing metadata
6. Submit for review on both platforms

## Team Orchestration

- You operate as the team lead and orchestrate the team to execute the plan.
- You're responsible for deploying the right team members with the right context to execute the plan.
- IMPORTANT: You NEVER operate directly on the codebase. You use `Task` and `Task*` tools to deploy team members to to the building, validating, testing, deploying, and other tasks.
  - This is critical. You're job is to act as a high level director of the team, not a builder.
  - You're role is to validate all work is going well and make sure the team is on track to complete the plan.
  - You'll orchestrate this by using the Task* Tools to manage coordination between the team members.
  - Communication is paramount. You'll use the Task* Tools to communicate with the team members and ensure they're on track to complete the plan.
- Take note of the session id of each team member. This is how you'll reference them.

### Team Members

- Builder
  - Name: builder-code-fixes
  - Role: Fix all code-level blockers (permissions, auth wiring, env vars, tab icons, downloads tab)
  - Agent Type: general-purpose
  - Resume: true

- Builder
  - Name: builder-eas-config
  - Role: Set up EAS Build, signing configuration, eas.json, and production build profiles
  - Agent Type: general-purpose
  - Resume: true

- Builder
  - Name: builder-store-assets
  - Role: Prepare store listing metadata, draft privacy policy, terms of service, and asset specifications
  - Agent Type: general-purpose
  - Resume: true

- Builder
  - Name: validator-final
  - Role: Validate all changes compile, builds succeed, and all store requirements are met
  - Agent Type: validator
  - Resume: false

## Step by Step Tasks

- IMPORTANT: Execute every step in order, top to bottom. Each task maps directly to a `TaskCreate` call.
- Before you start, run `TaskCreate` to create the initial task list that all team members can see and execute.

### 1. Remove Problematic Android Permissions
- **Task ID**: fix-android-permissions
- **Depends On**: none
- **Assigned To**: builder-code-fixes
- **Agent Type**: general-purpose
- **Parallel**: true (can run alongside tasks 2-5)
- Remove `SYSTEM_ALERT_WINDOW` permission from `android/app/src/main/AndroidManifest.xml`
- Remove `WRITE_EXTERNAL_STORAGE` permission (deprecated, not needed on Android 10+)
- Verify remaining permissions are appropriate for a book reader app

### 2. Wire AuthProvider into Root Layout
- **Task ID**: wire-auth-provider
- **Depends On**: none
- **Assigned To**: builder-code-fixes
- **Agent Type**: general-purpose
- **Parallel**: true
- Import and wrap the app with `AuthProvider` in `app/_layout.tsx`
- Ensure AuthProvider is inside QueryClientProvider but wraps the router/slot
- Test that the auth context is accessible from child screens

### 3. Fix Environment Variables and API URLs
- **Task ID**: fix-env-vars
- **Depends On**: none
- **Assigned To**: builder-code-fixes
- **Agent Type**: general-purpose
- **Parallel**: true
- Rename `NEXT_PUBLIC_SUPABASE_URL` to `EXPO_PUBLIC_SUPABASE_URL` in `lib/supabase.ts`
- Rename `NEXT_PUBLIC_SUPABASE_ANON_KEY` to `EXPO_PUBLIC_SUPABASE_ANON_KEY`
- Update `lib/api.ts` to use `EXPO_PUBLIC_API_URL` environment variable with a non-localhost production fallback
- Update `.env.example` or document required env vars

### 4. Replace Emoji Tab Icons with Proper Icons
- **Task ID**: fix-tab-icons
- **Depends On**: none
- **Assigned To**: builder-code-fixes
- **Agent Type**: general-purpose
- **Parallel**: true
- Install `@expo/vector-icons` if not already present (it ships with Expo)
- Replace emoji characters in `app/(tabs)/_layout.tsx` with proper Ionicons or MaterialIcons
- Use appropriate icons: book/library icon for Library tab, download/arrow-down icon for Downloads tab

### 5. Handle Downloads Tab (Minimum Viable or Remove)
- **Task ID**: fix-downloads-tab
- **Depends On**: none
- **Assigned To**: builder-code-fixes
- **Agent Type**: general-purpose
- **Parallel**: true
- Option A (recommended): Keep the tab but make the empty state clear and intentional ("Coming soon" or "Offline reading coming soon") so reviewers don't see it as broken
- Option B: Remove the downloads tab entirely until the feature is implemented
- Ensure whichever approach is taken, the app feels complete and not broken

### 6. Add Account Deletion Flow
- **Task ID**: add-account-deletion
- **Depends On**: wire-auth-provider
- **Assigned To**: builder-code-fixes
- **Agent Type**: general-purpose
- **Parallel**: false
- Both Apple and Google require apps with accounts to provide in-app account deletion
- Add a "Delete Account" option in a settings/profile section
- Implement confirmation dialog before deletion
- Call the appropriate API endpoint to delete the user's account and data
- Sign the user out after successful deletion

### 7. Create EAS Configuration
- **Task ID**: setup-eas-config
- **Depends On**: none
- **Assigned To**: builder-eas-config
- **Agent Type**: general-purpose
- **Parallel**: true (can run alongside code fixes)
- Create `eas.json` with three profiles: `development`, `preview`, `production`
- Development profile: uses development client, iOS simulator build
- Preview profile: internal distribution for testing on devices
- Production profile: App Store / Google Play submission builds
- Add `"submit"` config for both iOS (App Store Connect) and Android (Google Play)
- Add EAS scripts to `package.json`: `"build:ios"`, `"build:android"`, `"submit:ios"`, `"submit:android"`

### 8. Configure iOS Signing
- **Task ID**: setup-ios-signing
- **Depends On**: setup-eas-config
- **Assigned To**: builder-eas-config
- **Agent Type**: general-purpose
- **Parallel**: false
- Document that the user needs an Apple Developer Program membership ($99/year)
- Add `DEVELOPMENT_TEAM` to the EAS build config or document manual Xcode setup
- Configure `eas.json` production profile for iOS with `"autoIncrement": true` for build numbers
- EAS will handle certificate and provisioning profile generation automatically

### 9. Configure Android Signing
- **Task ID**: setup-android-signing
- **Depends On**: setup-eas-config
- **Assigned To**: builder-eas-config
- **Agent Type**: general-purpose
- **Parallel**: false
- Document keystore generation command: `keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -storepass <password> -keypass <password> -alias storia-upload -keystore storia-upload.keystore`
- Update `android/app/build.gradle` release signing config to reference the production keystore via environment variables (not hardcoded paths)
- Configure `eas.json` to use the upload keystore for Android production builds
- Note: Google Play App Signing will manage the actual distribution key

### 10. Prepare Store Listing Metadata
- **Task ID**: prepare-store-metadata
- **Depends On**: none
- **Assigned To**: builder-store-assets
- **Agent Type**: general-purpose
- **Parallel**: true
- Draft app name: "Storia" (6 chars, well within 30-char limit)
- Draft subtitle (iOS): "Interactive Stories & Audiobooks" or similar
- Draft short description (Android, 80 chars): "Discover and read beautifully illustrated stories with narration"
- Draft full description (4000 chars max) highlighting: illustrated stories, audio narration, word-by-word highlighting, offline reading (if implemented), custom fonts, dark mode
- Draft keywords (iOS, 100 chars): story,audiobook,reader,children,books,narration,illustrated,ebook,reading
- Identify primary category: Books (both platforms)
- Save all metadata to `specs/store-listing-metadata.md`

### 11. Draft Privacy Policy and Terms of Service
- **Task ID**: draft-legal-docs
- **Depends On**: none
- **Assigned To**: builder-store-assets
- **Agent Type**: general-purpose
- **Parallel**: true
- Draft privacy policy covering: data collected (email for auth, reading progress, device info), Supabase as data processor, no tracking/advertising, data retention, user rights (access, deletion), GDPR compliance, COPPA considerations
- Draft terms of service covering: acceptable use, account management, content licensing, limitation of liability
- Save to `specs/privacy-policy-draft.md` and `specs/terms-of-service-draft.md`
- Note: These will need to be hosted at public URLs before submission

### 12. Document Store Asset Requirements
- **Task ID**: document-asset-requirements
- **Depends On**: none
- **Assigned To**: builder-store-assets
- **Agent Type**: general-purpose
- **Parallel**: true
- Document exact screenshot dimensions needed:
  - iOS: 6.9" iPhone (1320x2868), 6.5" iPhone (1284x2778), 12.9" iPad Pro (2048x2732)
  - Android: phone screenshots (min 320px, recommended 1080x1920+)
- Document feature graphic requirement: 1024x500 PNG/JPEG for Google Play
- Verify `assets/icon.png` is exactly 1024x1024 and has no transparency
- Verify `assets/adaptive-icon.png` meets Android adaptive icon specs
- Document app preview video specs (optional but recommended)
- Save checklist to `specs/store-assets-checklist.md`

### 13. Prepare Privacy Nutrition Labels & Data Safety Mappings
- **Task ID**: prepare-privacy-labels
- **Depends On**: draft-legal-docs
- **Assigned To**: builder-store-assets
- **Agent Type**: general-purpose
- **Parallel**: false
- Map all data collected by the app and its SDKs:
  - Auth: email address, authentication tokens (Supabase)
  - Usage: reading progress, book interactions (@tanstack/react-query cache)
  - Device: none collected beyond standard expo diagnostics
  - Tracking: none (NSPrivacyTracking already set to false)
- Create Apple Privacy Nutrition Label responses document
- Create Google Play Data Safety section responses document
- Save to `specs/privacy-data-mappings.md`

### 14. Validate All Code Changes
- **Task ID**: validate-code-changes
- **Depends On**: fix-android-permissions, wire-auth-provider, fix-env-vars, fix-tab-icons, fix-downloads-tab, add-account-deletion
- **Assigned To**: validator-final
- **Agent Type**: validator
- **Parallel**: false
- Verify `SYSTEM_ALERT_WINDOW` and `WRITE_EXTERNAL_STORAGE` are removed from AndroidManifest.xml
- Verify AuthProvider is properly wired in `app/_layout.tsx`
- Verify no references to `NEXT_PUBLIC_*` env vars remain
- Verify `lib/api.ts` does not default to localhost
- Verify tab icons use proper icon components (no emoji)
- Verify downloads tab has a polished empty/coming-soon state
- Verify account deletion flow exists
- Run TypeScript compilation check: `npx tsc --noEmit`
- Run `npx expo-doctor` to check for common issues

### 15. Validate Build Configuration
- **Task ID**: validate-build-config
- **Depends On**: setup-eas-config, setup-ios-signing, setup-android-signing, validate-code-changes
- **Assigned To**: validator-final
- **Agent Type**: validator
- **Parallel**: false
- Verify `eas.json` exists and has valid development, preview, and production profiles
- Verify `app.json` has correct bundle identifier, version, and required fields
- Verify Android `build.gradle` release signing does NOT reference debug.keystore
- Verify iOS build settings reference a valid team ID or EAS-managed signing
- Run `eas build --platform all --profile production --non-interactive --no-wait` (dry-run if possible) to verify config

### 16. Final Submission Readiness Validation
- **Task ID**: validate-all
- **Depends On**: validate-code-changes, validate-build-config, prepare-store-metadata, draft-legal-docs, document-asset-requirements, prepare-privacy-labels
- **Assigned To**: validator-final
- **Agent Type**: validator
- **Parallel**: false
- Run all validation commands listed below
- Create a final readiness checklist with pass/fail for each requirement
- Document any remaining manual steps the developer must complete (Apple Developer enrollment, Google Play Console setup, screenshot capture, etc.)
- Save final report to `specs/submission-readiness-report.md`

## Acceptance Criteria
- All `SYSTEM_ALERT_WINDOW` and `WRITE_EXTERNAL_STORAGE` permissions removed from Android manifest
- AuthProvider is wired into the app root layout
- All environment variables use `EXPO_PUBLIC_*` prefix convention
- API client uses production URL (not localhost) by default
- Tab bar uses proper vector icons (no emoji)
- Downloads tab has polished coming-soon state or is removed
- Account deletion flow is implemented
- `eas.json` exists with development, preview, and production profiles
- Android release signing is configured with a production keystore (not debug.keystore)
- iOS signing is configured (Team ID or EAS-managed)
- Store listing metadata drafted for both platforms
- Privacy policy and terms of service drafted
- Privacy nutrition labels / data safety mappings documented
- All store asset requirements documented with exact specs
- TypeScript compiles without errors (`npx tsc --noEmit`)
- `npx expo-doctor` passes without critical issues

## Validation Commands
Execute these commands to validate the task is complete:

- `npx tsc --noEmit` — Verify TypeScript compilation
- `npx expo-doctor` — Check for common Expo issues
- `grep -r "SYSTEM_ALERT_WINDOW" android/` — Should return no results
- `grep -r "WRITE_EXTERNAL_STORAGE" android/` — Should return no results
- `grep -r "NEXT_PUBLIC_" lib/` — Should return no results (all renamed to EXPO_PUBLIC_)
- `grep -r "localhost:3000" lib/` — Should return no results
- `cat eas.json | python3 -m json.tool` — Verify eas.json is valid JSON
- `grep -r "debug.keystore" android/app/build.gradle` — Should NOT appear in release signing config
- `ls specs/store-listing-metadata.md specs/privacy-policy-draft.md specs/terms-of-service-draft.md specs/store-assets-checklist.md specs/privacy-data-mappings.md` — All spec files exist

## Notes
- **Apple Developer Program** ($99/year) enrollment is a prerequisite — the developer must handle this manually
- **Google Play Developer Account** ($25 one-time) registration is a prerequisite — the developer must handle this manually
- Screenshots must be captured on actual devices or simulators at the correct resolutions — this is a manual step after the app is building successfully
- The privacy policy and terms of service drafts will need legal review before hosting
- The app currently has `newArchEnabled: true` (React Native New Architecture) — this is fine for store submission but may surface edge-case bugs; test thoroughly
- Both `expo-av` and `expo-audio` are included as dependencies — consider consolidating to reduce bundle size
- The `.env` file must have production values set before building release binaries
- Consider setting up `expo-updates` for OTA updates post-launch
