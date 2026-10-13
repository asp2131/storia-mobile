# Story-first Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a polished story-first entry experience with a real account-free sample, protected parent setup, reliable on-device continuation, and measurable first-session value.

**Architecture:** Keep `JourneyPolicy` as the single routing authority and reuse the existing reader/runtime. Introduce a bundled sample source with enforced reader capabilities, a small local checkpoint store, and an entry-state notifier separate from App Review state. Port an approved cover-driven prototype into the existing entry screens, then integrate completion and return visits.

**Tech Stack:** Flutter/Dart, Riverpod 2.x without codegen, GoRouter, SharedPreferences, existing Supabase auth, existing audio/reader engines; no new analytics SDK or animation library.

**Spec:** `docs/superpowers/specs/2026-10-05-story-first-onboarding-design.md` — read this and `design/entry-flow/DIRECTION.md` before execution. The spec is a proposed contract; Task 1 obtains visual/content approval before implementation.

## Global Constraints

- Flutter single package, `flutter_riverpod ^2.6.1`, `go_router ^15.1.2`; no codegen.
- Mockups first in `design/entry-flow/`; approved Flutter port second.
- New polished, cozy, cover-driven entry design; not paper/sketch/watercolor, neo-brutalism, thick black borders, hard offset shadows, or halftones.
- No mascots or animals in new UI, mockup copy, or bundled sample; do not invent characters. Use approved human-made artwork, objects, places, weather, and sound imagery.
- Keep Sign in with Apple on iOS, existing supported Google sign-in, email magic link plus six-digit OTP, and `app-review@storia.kids` bypass.
- Keep the parental gate, lockout behavior, and 18+ parent birth-year check. These are product safeguards, not a claim of legally sufficient parental consent.
- Purchases and external parent actions remain behind the parental gate. No kid-facing paywalls, coins, wait-or-pay mechanics, advertising, or third-party tracking surfaces.
- Child setup collects nickname and age range only. No mandatory parent-goal quiz, exact child birthday, or reading-level diagnosis.
- Guest sample cannot activate a Supabase session or the App Review bypass. No guest microphone, speech recognition, recording, generated activities, parent voice library, backend pronunciation calls, or analytics upload.
- `JourneyPolicy` remains pure Dart and the sole routing authority. Keep a stable router; pair every new snapshot state source with a router refresh source.
- Use named theme/motion/spacing tokens, relative production imports, and `package:loratone/` test imports. Scope the new visual treatment to entry/continuation surfaces; no unrelated whole-app restyle.

## Decisions and release gates

1. **One real bundled sample, not public access to the regular catalog.** No database policy relaxation and no fake account/review bypass.
2. **On-device saves first.** Copy must say where progress is saved; no promise of cross-device sync without backend work.
3. **No quiz before value.** Age/nickname belong to parent profile setup. A goal or preference only belongs in the flow after a consumer actually uses it; no goal question in this cutover.
4. **No automatic library detour for first read.** Intro starts sample; successful save returns to its checkpoint. Authenticated returning users still enter their library.
5. **No new series/manga backend in this project.** Use the existing book reader and real published books for continuation. Do not invent series ordering or age-personalized picks from unavailable metadata.
6. **No silent scope substitution.** If approved sample assets are unavailable, finish the prototype/technical plan but do not ship an auth CTA labeled Try a story. If measurement collection is not approved, report that all-entrant retention cannot yet be established.
7. **No blind Flutter setup mutation.** Use the pinned SDK and `--no-pub` after intentional dependency setup. The earlier review attempt auto-updated lockfile/analyzer config; those changes were reverted. Avoid `flutter create .` in this checkout.
8. **Safe startup prerequisite.** `lib/main.dart` currently loads `.env`, and `pubspec.yaml` lists it as an asset, contrary to the latest `.wolf/cerebrum.md` client-only-config rule. Do not inspect or copy secrets into this plan. Before distributing any proof build, verify the shipped configuration contains client-safe values only; resolve unsafe packaging with the config owner before release.

## Existing implementation facts

| Concern | Evidence | Consequence |
|---|---|---|
| Intro | `lib/src/features/auth/presentation/intro_screen.dart` | Fixed 320px Rive hero, abstract copy, two large auth buttons; replace entry composition rather than add another carousel. |
| Routing | `lib/src/routing/journey/journey_policy.dart` | Signed-out allowlist currently contains only intro/sign-in/sign-up; profile gating and review gating are separate. |
| Auth | `lib/src/features/auth/presentation/sign_up_screen.dart` and `sign_in_screen.dart` | Preserve magic-link + OTP and router-owned post-auth advancement. |
| Parent step | `lib/src/features/onboarding/presentation/parent_birth_year_screen.dart` | Gate/year is currently backed by review state; production parent flow needs its own state. |
| Review form | `lib/src/features/onboarding/presentation/review_onboarding_screen.dart` | Nickname, age, and goal are mandatory today; remove unused goal requirement and migrate existing local records. |
| Child form | `lib/src/features/child/presentation/add_child_screen.dart` | Name/age required, reading level optional; simplify first-time setup while preserving existing profile editing behavior. |
| Content | `lib/src/data/book_repository.dart`, `providers.dart` | Supabase reads regular catalog/content; sample must resolve before those providers are instantiated. |
| Reader | `lib/src/features/reader/reader_screen.dart` | New book starts at zero; narration selection, manifest fetch, controller, and walkthrough are initialized. Sample and checkpoint support must reach below the UI. |
| Completion | `lib/src/features/reader/celebration/book_celebration_screen.dart` | Existing celebration ends in Back to Library; extend it rather than build a second celebration. |
| Proof script | `bin/symphony-capture-playwright-proof.sh` | Assumes old CTA/goal fields, may seed review storage, and refuses an existing `web/` missing `index.html`; cannot serve as unchanged end-to-end proof. |
| Existing backend progress | `../storia/src/app/api/reading-progress/route.ts`, `reading-sessions/route.ts`, `continue-reading/route.ts` | Real sibling APIs exist, but Flutter does not consume them. Progress expects positive numeric book IDs and one-based pages; the reserved local sample ID cannot be uploaded. Deployment/conflict semantics are unverified. Reuse these contracts if cloud sync is later approved; do not create competing endpoints. |
| Completion metrics | `lib/src/features/reader/runtime/reader_analytics_tracker.dart` | Existing `book_completed` means last page visited, not explicit Finish. Keep historical meaning separate from the new durable completion definition. |

## Execution order and ownership

```text
Task 1: approved prototype + real content package
    -> Task 2: sample source/capability boundary
    -> Task 3: local checkpoints and restore
    -> Task 4: entry policy + protected parent/auth/profile flow
    -> Task 5: approved UI port and integrated first session
    -> Task 6: completion and next-visit experience
    -> Task 7: operational measurement + end-to-end release proof
```

Tasks 2 and 3 can be developed in parallel after contracts are agreed, with one integration owner for reader/provider edits. Do not overlap Task 4 and Task 5 edits to auth/onboarding files. No feature is publicly enabled until the complete changed journey passes Task 7. Keep this a clean cutover, not a permanent second onboarding variant. A later approved experiment may control cohort assignment; this plan does not add an unverified experimentation service.

## File structure and proposed interfaces

New files are explicitly proposed; existing paths above are verified. Do not create every proposed file as an empty scaffold.

| New path | Responsibility |
|---|---|
| `design/entry-flow/story-first.html` | Linked responsive prototype using approved art and final copy. |
| `assets/onboarding/sample/manifest.json` | Versioned metadata and local asset references for the complete sample. |
| `lib/src/features/onboarding/domain/entry_flow_state.dart` | Immutable entry state, auth intent, parent authorization, validated return target. |
| `lib/src/features/onboarding/data/entry_flow_provider.dart` | Hydration and mutations; short-lived parent access; router refresh source. |
| `lib/src/features/onboarding/data/sample_book_provider.dart` | Decode approved sample bundle into existing `Book`/`PageData`. |
| `lib/src/features/onboarding/presentation/sample_reader_screen.dart` | Establish sample source/capabilities, then mount the existing `ReaderScreen`; no duplicate renderer. |
| `lib/src/features/onboarding/presentation/save_story_screen.dart` | Parent-facing explicit claim confirmation and write-error recovery. |
| `lib/src/features/reader/domain/reader_capabilities.dart` | Explicit sample/catalog runtime permissions. |
| `lib/src/features/reader/domain/reading_checkpoint.dart` | Versioned local position and owner types. |
| `lib/src/features/reader/data/reading_checkpoint_repository.dart` | Serialized SharedPreferences read/write/claim; no backend analytics. |
| `lib/src/features/reader/data/reading_checkpoint_provider.dart` | Scope repository to current guest/account/child and surface hydration/errors. |
| `lib/src/features/library/widgets/reading_continuation_card.dart` | Resume/saved-next UI without restructuring the map. |
| `lib/src/core/theme/entry_flow_theme.dart` | Scoped entry ThemeData built from approved central tokens. |
| `lib/src/core/media/reader_media_source.dart` | Shared asset/network source parsing and image-provider choice for renderer, image readiness, and completion cover; audio must not import reader feature internals. |

Planned contract names, implemented in Tasks 2–4:

```dart
enum ReaderAccess { sample, catalog }
enum EntryAuthIntent { signIn, signUp }
enum CheckpointClaimResult { saved, alreadySaved, existingProgress }

// Reader capabilities are selected at the trusted route/source boundary.
// Do not infer permission from a user-controlled arbitrary book ID.
class ReaderCapabilities {
  const ReaderCapabilities({required this.access});
  final ReaderAccess access;
  bool get allowsNetworkContent => access == ReaderAccess.catalog;
  bool get allowsSpeech => access == ReaderAccess.catalog;
  bool get allowsWordHelp => access == ReaderAccess.catalog;
  bool get allowsParentNarration => access == ReaderAccess.catalog;
  bool get allowsActivities => access == ReaderAccess.catalog;
  bool get allowsAnalytics => access == ReaderAccess.catalog;
}
```

`ReadingOwner` has const named constructors `ReadingOwner.guest()` and `ReadingOwner.child({required String userId, required String childId})`; reject blank user/child IDs. `ReadingCheckpoint` has a const constructor with required named `String bookId`, `String contentRevision`, `String pageId`, `int pageIndex`, `bool completed`, `DateTime updatedAt`, and optional `String? savedNextBookId`. Its encoding is versioned. Sample revision comes from the bundle; catalog structural revision is a deterministic SHA-256 of the ordered page IDs, not a claim of server publication versioning. Repository API:

```dart
abstract interface class ReadingCheckpointRepository {
  Future<ReadingCheckpoint?> load(ReadingOwner owner, String bookId);
  Future<void> save(ReadingOwner owner, ReadingCheckpoint checkpoint);
  Future<List<ReadingCheckpoint>> loadAll(ReadingOwner owner);
  Future<CheckpointClaimResult> claimSample({
    required ReadingOwner child,
    required String bookId,
    required bool replaceExisting,
  });
  Future<void> removeOwner(ReadingOwner owner);
}
```

The concrete implementation is `PreferencesReadingCheckpointRepository(SharedPreferences preferences)`. Claims are copy-first, with explicit existing-progress conflict handling; a failed destination write never erases the guest record. Do not promise crash-atomic multi-key transactions from SharedPreferences.

Reading ownership and reader capabilities are independent: after explicit claim, a selected child resumes the bundled sample from that child's checkpoint while all sample network/speech restrictions remain enforced. A different account/child does not inherit that claim. The continuation provider selects the newest unfinished record from `loadAll`, otherwise the newest explicit saved-next record; it cannot use only the most recently completed book and overlook unfinished reading.

---

### Task 1: Approve the flow, visual system, and real sample package

**Files:** create `design/entry-flow/story-first.html`; update `design/entry-flow/DIRECTION.md`; add approved files under `assets/onboarding/sample/`; update `pubspec.yaml` asset/font declarations only when real files exist.

**Consumes:** spec and latest design preferences. **Produces:** approved linked screen states, named design tokens, final copy, and a complete sample bundle ready for the reader.

- [ ] Build the prototype with real content-owner-provided art. Cover intro -> sample -> completion -> grown-up gate -> year -> auth/OTP -> nickname/age -> save confirmation -> continued reading. Include returning account/profile selection and returning guest variants.
- [ ] Use this initial copy for review, not the old abstract positioning:

```text
Intro heading: Stories worth one more page.
Intro body: Explore illustrated stories with sound that brings each page to life.
Primary: Try a story
Secondary: Parent sign in
Returning guest primary: Continue story
Reader cue: Swipe up for the next page
Completion parent action: Ask a grown-up to save
Parent benefit: Keep your place for next time.
Save disclosure: Saved on this device for this reader.
Optional exit: Not now
```

- [ ] Keep sample sound silent until explicit activation. Prototype static artwork, image/audio error states, loading, denied gate, invalid year, failed auth, existing-progress conflict, and failed save. Do not fabricate trust claims, founder identities, prices, or notification frequency.
- [ ] Obtain a content package with stable ID/revision, title/author/rights, cover, every page/text overlay, narration timestamps/audio, soundscape, fonts/licenses, and age suitability. Reserve ID `loratone-entry-sample` for the bundled source; regular catalog IDs cannot resolve to it. Do not invent content to satisfy this task.
- [ ] Verify prototype at 320x568, 390x844, 430x932, and tablet with 1x/2x text and reduced motion. Capture actual linked interactions, not just separate static frames. Have the user approve visual direction/content before Task 2 production changes.
- [ ] Update the direction document to mark obsolete 17-screen quiz/plan/notification screens as reference, not implementation scope; retain required safeguards. Commit only approved design/content work after review.

**Acceptance:** no placeholder artwork; a family can understand the product and reach the sample without completing a form. Content owner approval is a hard dependency, not a later polish item.

### Task 2: Make the existing reader safe for a genuine offline sample

**Files:** create sample provider/wrapper, capabilities, and `reader_media_source.dart`; modify `lib/src/data/providers.dart`, `lib/src/features/narration_studio/data/narration_providers.dart`, `lib/src/features/reader/reader_screen.dart`, `page_renderer.dart`, `application/reader_experience_controller.dart`, `runtime/providers/reader_session_provider.dart`, `runtime/providers/reader_word_help_provider.dart`, `runtime/reader_session_impl.dart`, `lib/src/audio/page_audio.dart`, `audio_engine.dart`, and `just_audio_player.dart`. Update `pubspec.yaml` for supplied assets/fonts and all affected `PageAudio` implementations/fakes found by LSP.

**Consumes:** approved asset bundle. **Produces:** a sample-scoped existing reader that does not initialize prohibited services.

- [ ] Before changing exported reader/provider signatures, use LSP references and enumerate all callers and test overrides. Read `.wolf/buglog.json` before any associated bug fix; preserve ordinary catalog behavior and parent-recorded narration.
- [ ] Decode a versioned sample manifest directly into existing `Book`/`PageData` constructors. Do not feed flat soundscape fields through `PageData.fromJson`: that parser obtains soundscape from relational assignments/scenes, and its `copyWith(null)` cannot clear remote URLs. Use the approved manifest's explicit local image/narration/soundscape paths, overlay, timestamps, stable page IDs, and numeric order. Reject missing pages/files, duplicate IDs, or remote sample references during content validation; show an honest unavailable state rather than substituting catalog data.
- [ ] Implement sample resolution before constructing Supabase-backed catalog, pronunciation, or narration providers. Add route-scoped capabilities and explicitly scoped controller/session assembly. The current session/analytics/audio providers are shared, so a nested capability override alone is not sufficient: ensure the session depends on the scoped capability/source providers and deterministically ends before switching modes. Never reuse an account analytics tracker in sample mode, even after auth/profile state becomes available.
- [ ] Use `asset:///assets/onboarding/sample/...` for sample media references. One `ReaderMediaSource.parse(String)` produces either a validated bundled asset path or an HTTP(S) resource. Expose `ImageProvider<Object> imageProviderForReaderSource(String source)` from `reader_media_source.dart`; use it for `PageRenderer` dimension resolution, page rendering, session image-ready probing, and completion cover. `JustAudioPlayer.setSource` dispatches asset sources to `setAsset(uri.path.substring(1))` and ordinary URLs to `setUrl`; retain the existing player/engine, not a duplicate media pipeline.
- [ ] Enforce these rules below the UI: no speech service initialization, microphone request, manifest fetch, pronunciation HTTP, narration-library query, generated activities, session analytics, or analytics upload for sample. Do not implement placeholder services that pretend success. Skip unavailable operations through explicit capability checks and lazy dependencies.
- [ ] Extend `PageAudio.loadPage(PageData page, {bool autoplay = true})` and migrate every implementation/caller/fake. Sample session starts with autoplay false; explicit playback enables sound for later sample page loads. Loading an asset must not play either channel, including an already loaded same-soundscape branch. Preserve catalog autoplay behavior. On lifecycle resume require explicit play in sample mode; retain mix levels but do not resume sound unexpectedly.
- [ ] Add a permanent capability boundary test using the existing reader fakes: network/speech factories increment counters or fail the test if constructed; start sample, advance a page, request unavailable actions, background, and end it; assert zero prohibited calls and correct visible page/playback state. Keep the ordinary reader behavior suite.
- [ ] Pause/end and persist before navigating to parent UI or celebration, not only on app background. Invalidate outstanding session image/audio load requests before awaiting stop so a late image-ready callback cannot restart sound underneath auth. Extend `test/features/reader/runtime/reader_session_image_gate_test.dart` with end-during-image-load and next-launch isolation; treat the race as a hypothesis until a failing regression establishes it.
- [ ] Extend `test/audio/audio_engine_test.dart`, `test/features/reader/page_renderer_image_fit_test.dart`, `test/features/reader/application/reader_experience_controller_test.dart`, and `test/features/reader/runtime/reader_session_analytics_test.dart`. Add `test/features/onboarding/sample_reader_test.dart` that mounts the real shared controller/session (not a mocked coordinator) with prohibited dependency factories that fail if invoked.
- [ ] Smoke the real sample on iOS and browser with network disabled from a fresh signed-out launch, confirming artwork, narration, soundscape, page advance, and replay. Inspect outgoing requests and OS permission prompts; a passing mock test alone is not offline proof.

**Verification:** targeted reader/application/runtime tests and actual offline reading. Catalog narration and word-help smoke still work after leaving sample mode. Add the tested sample capability/content contract to the README after proof.

### Task 3: Save and restore local reading position without cross-child leakage

**Files:** create checkpoint domain/repository/provider files above; modify `lib/src/features/reader/reader_screen.dart` and `lib/src/features/reader/application/reader_experience_controller.dart`; add `test/features/reader/reading_checkpoint_repository_test.dart`; update `test/features/reader/reader_screen_coordinator_test.dart`.

**Consumes:** real sample/catalog reader. **Produces:** on-device guest/account-child checkpoint persistence, restore, and explicit claim API.

- [ ] Implement the contract above with a versioned JSON namespace. Validate revision/index/page ID on read. Corrupt/unknown-version records must not crash the reader or be treated as completed. Never persist names, email, audio, or word events.
- [ ] Preserve a checkpoint when unavailable assets/network prevent opening its book. On content revision changes, resolve saved page ID first; if missing, clamp the saved index to the new valid page range. Do not mark the new revision completed unless that completion remains valid.
- [ ] Serialize writes per owner/book so an older asynchronous page save cannot overwrite a newer one. Flush on page change/completion and before auth navigation; await save on those explicit boundaries. No per-frame writes. Surface a failed explicit Save as a recoverable error, not success.
- [ ] Restore the physical `PageController` position and `ReaderExperienceStart.initialPageIndex` from the same resolved checkpoint before the first visible page. Do not restore only logical state while showing page zero. Parent voice switches preserve the currently visible page.
- [ ] Add this complete repository conflict test once the proposed domain/repository types exist. The test verifies a consumer-visible ownership boundary, not serialization wording:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/reader/domain/reading_checkpoint.dart';
import 'package:loratone/src/features/reader/data/reading_checkpoint_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('claim never replaces a child position without confirmation', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = PreferencesReadingCheckpointRepository(
      await SharedPreferences.getInstance(),
    );
    const sampleId = 'loratone-entry-sample';
    const child = ReadingOwner.child(userId: 'parent-a', childId: 'reader-a');
    ReadingCheckpoint checkpoint(int index) => ReadingCheckpoint(
      bookId: sampleId,
      contentRevision: '1',
      pageId: 'page-$index',
      pageIndex: index,
      completed: false,
      updatedAt: DateTime.utc(2026, 10, 5),
    );
    await repository.save(child, checkpoint(4));
    await repository.save(const ReadingOwner.guest(), checkpoint(2));

    final result = await repository.claimSample(
      child: child,
      bookId: sampleId,
      replaceExisting: false,
    );

    expect(result, CheckpointClaimResult.existingProgress);
    expect((await repository.load(child, sampleId))!.pageIndex, 4);
    expect(
      (await repository.load(const ReadingOwner.guest(), sampleId))!.pageIndex,
      2,
    );
  });
}
```

Also cover failed destination writes, repeat claims, user/child switching, corrupt records, out-of-order write completion, and completed-story reopen/replay as distinct actions. Use hand-written failure fakes, no codegen. Capture positions before `ReaderEnd` resets session state to zero; teardown snapshots must not overwrite a valid bookmark. Resume is page-level, not an unimplemented exact-audio-offset promise.
- [ ] Make claim idempotent: identical destination -> `alreadySaved`; different existing destination -> `existingProgress` unless the parent explicitly chooses replacement; successful write -> `saved`. Keep guest record until success and do not replay guest analytics.
- [ ] Smoke read page 2 -> terminate/relaunch -> same page; auth cancellation -> same page; claim to child A -> child B sees no A continuation; sign out -> no previous account continuation. A completed sample should offer replay, not silently reset history.

**Verification:** run the checkpoint repository/coordinator tests and record the restart/account-switch smoke. State explicitly that sync is local, not cross-device.

### Task 4: Make the protected parent journey and post-auth return deterministic

**Files:** create entry state/provider and save-story screen above; modify all four `lib/src/routing/journey/` files plus `lib/src/routing/app_router.dart`; modify parent-birth-year screen, review onboarding screen/model/provider, sign-in/up screens, child add/picker screens. Update `test/routing/journey/` and `test/features/child/add_child_screen_test.dart`; add `test/features/onboarding/entry_flow_test.dart`.

**Consumes:** checkpoint persistence and existing gate/auth/profile operations. **Produces:** explicit sample entry, parent access protection, compact setup, and validated return after save.

- [ ] Extend route constants with `sampleReader = '/try-story'` and `saveStory = '/save-story'`. Sample route has no arbitrary book parameter. Add screen verbs `startSample`, `requestParentEntry`, and `confirmSampleSave`; these own mutation-before-navigation and mounted checks. `requestParentEntry` accepts `EntryAuthIntent` and a validated sample return intent, never a free-form URL.
- [ ] Define immutable `EntryFlowState` with readiness, pending `EntryAuthIntent?`, parent authorization status, adult-year verification status, and pending sample-save intent. Do not put guest access into `AppReviewFlowState`. Use a single notifier with disposal/async guards; do not double-dispose ChangeNotifierProviders.
- [ ] Parent action opens the existing `ParentalGate.verify`; only success grants temporary access to the year/auth flow. Deep linking to auth or save cannot grant it. Route the existing parent year screen through the entry state for normal accounts and preserve review-track storage behavior where required.
- [ ] `ParentBirthYearScreen` skips its internal challenge only when entry state holds a still-valid passed gate; otherwise it shows the existing challenge. When activating the reviewer bypass clears review preferences, copy the already verified year from the active parent flow into review state before policy continuation. A direct legacy reviewer route still enforces the original safeguards.
- [ ] Use a ten-minute in-memory parent access window, invalidated on ordinary background/cold launch/sign-out. An explicitly started OAuth or mail-code round trip may retain only that pending parent/auth intent within the same window; arbitrary foregrounding does not grant access. Cold-start auth callbacks may establish the backend session but must re-enter the parent gate before any parent-only continuation. Preserve checkpoints when re-gating.
- [ ] Keep the 18+ year check and existing challenge lockout. Inject clock into validation tests instead of hardcoding 2026. Keep raw birth year out of analytics and never call the year check verified parental consent.
- [ ] Define the route policy from this table; extend truth-table tests for both `redirect` and `nextLocation`:

| State/action | Destination / allowed behavior |
|---|---|
| Cold signed-out root | Intro; unfinished sample changes intro CTA, not an automatic audio-start. |
| Signed-out `/try-story` | Sample only; no catalog/profile/settings access. |
| Unhydrated entry state | Hold at safe boot/intro; protected route widgets must not initialize. |
| Parent action cancelled/locked | Stay in sample/intro with checkpoint intact. |
| Parent auth link without access | Gate before parent UI; retain only validated destination. |
| Gate passed, year pending | Parent year step. |
| Adult parent, no session | Requested sign-in/sign-up. |
| Auth success, zero profiles | Compact add-child form directly. |
| Auth success, existing profiles and guest save pending | Explicit child selection/confirmation; never silently attach guest history. |
| Child selected, guest save pending | Save confirmation, then same sample position or completed state. |
| Authenticated normal launch | Existing profile-selection rules -> library. |
| Reviewer bypass | Existing review safeguards -> nickname/age setup -> library; no backend child required. |
| Sample URL under complete account | Sample reader remains admissible so continuation works. |

- [ ] Preserve `redirect(snapshot, nextLocation(snapshot)) == null` for every settled snapshot and avoid navigation loops. Include entry notifier in the stable router's `refreshListenable`. Continue to let the redirect backstop own auth success; do not restore screen-side auth listeners.
- [ ] Remove parent-goal collection, enum, and mandatory serialized field once references are migrated. Decode legacy review records that still contain `parentGoal` by ignoring it; do not discard completed setups. Use the existing review bands `4-6`, `7-9`, `10-12` for new/review first-child setup, matching the documented 4–12 product audience. Preserve previously saved child age-band strings and do not silently reinterpret an existing child's age. Content-owner review must confirm the starter is suitable for the offered bands before release.
- [ ] Remove reading-level/default-profile questions from first-child onboarding only. Preserve stored reading-level data and existing profile-management functionality. Automatically mark the sole first child as default; do not change another existing default as a side effect of onboarding.
- [ ] In save confirmation, handle destination-write failure without clearing guest data or navigating away. Handle `existingProgress` by showing Keep existing / Use this story position; respect the selected child and do not overwrite silently.
- [ ] Replace the copied-router harness in `auth_auto_advance_regression_test.dart` with behavior coverage against the production router and safe provider overrides. Do not pin source text or a duplicate route wiring implementation. Retain tests for OTP, gate lockout, reviewer migration, missing profile, cancellation, callback relock, and no cross-child claim.

**Verification:** run journey, auth, onboarding, gate, and child behavior tests. Smoke both normal-account and reviewer tracks; reviewer success is not evidence of normal-account success.

Targeted commands after each relevant implementation slice:

```bash
flutter test test/features/onboarding/sample_reader_test.dart test/features/reader/runtime/ test/audio/audio_engine_test.dart
flutter test test/features/reader/reading_checkpoint_repository_test.dart test/features/reader/reader_screen_coordinator_test.dart
flutter test test/routing/journey/ test/features/auth/ test/features/onboarding/ test/features/child/ test/core/widgets/gate_controller_test.dart test/core/widgets/gate_lockout_test.dart
```

Write boundary tests before their implementation and observe their meaningful failing state, then run the affected group once after the edit batch. Do not run tests/formatters mid-flight in concurrent workers; the integration owner runs them after shared edits settle. Do not preserve incidental source/wiring tests merely to make these commands pass.

### Task 5: Port the approved intro and setup design

**Files:** modify `intro_screen.dart`, auth `sign_in_screen.dart` / `sign_up_screen.dart` / `widgets/auth_screen_shell.dart`, parent-year and review-onboarding screens, child add/picker entry composition, save-story screen; create `lib/src/core/theme/entry_flow_theme.dart`; extend existing central token files only with approved semantic tokens.

**Consumes:** approved prototype, working routes/sample/save. **Produces:** cohesive production UI, not a static preview or second design system.

- [ ] Use scoped ThemeData plus stock accessible Material controls where they fit. Remove entry-only watercolor/leaf/Rive/cloud/sparkle composition and sketch treatment from these surfaces; do not globally restyle unrelated screens or delete assets still used elsewhere.
- [ ] Build intro around real cover/page art. One primary action calls `startSample`; quiet parent sign-in calls `requestParentEntry`. The hero is responsive, not a fixed 320px box. Loading/failure retains static approved art; no blank hero.
- [ ] Connect Continue story to persisted guest state, and keep a separate replay action for completed samples. No strings may promise saving until the save contract is actually wired.
- [ ] Replace verbose signup copy with direct parent benefits while retaining Apple and OTP recovery. Use autofill/input actions and inline errors; disabled/busy states must not erase form values. Back preserves nickname/age drafts without logging child data.
- [ ] Limit reader guidance to a contextual vertical swipe cue and explicit sound activation. Reuse/adjust existing walkthrough persistence so experienced users do not get a second full walkthrough and guest first-read does not consume unrelated catalog tutorials.
- [ ] Keep transitions short and interaction-led; no delay before the CTA becomes usable. Preserve semantics/focus order and reduced-motion behavior. Confirm 48px targets, contrast, keyboard visibility, text scaling, and short screens.
- [ ] Browser-verify every actual surface against the approved prototype; capture screenshots/video at specified sizes. Use existing behavior tests where changed contracts break; do not add permanent tests asserting exact marketing copy, pixel defaults, or widget wrappers.

**Verification:** real intro -> sample -> parent flow -> save -> resume on small phone and tablet, with reduced motion and keyboard. Update README entry-flow documentation only after this smoke succeeds.

### Task 6: Connect completion to a useful next visit

**Files:** modify `lib/src/features/reader/reader_screen.dart`, `lib/src/features/reader/celebration/book_celebration_screen.dart`, `book_celebration_summary.dart`, `lib/src/features/library/library_screen.dart`; create continuation card; update celebration tests and checkpoint behavior tests.

**Consumes:** checkpoints, published book catalog, existing celebration. **Produces:** accessible completion, save-for-later, and child-scoped continuation.

- [ ] Add a visible last-page Finish action; retain intentional overscroll as an alternative, sharing a single guarded completion transition. Set checkpoint completed before navigation; rebuild/back/overscroll cannot emit a second completion for the same attempt.
- [ ] Extend `BookCelebrationSummary` with the actual `bookId` and sample/catalog context; never match identity by title. For the new sample surface replace the existing mascot-era Lottie with approved non-character artwork or a restrained type/cover celebration. Show title and completion, not unverified full-book pages-read counts or rounded-up engaged minutes.
- [ ] Guest completion offers replay and parent save, with no library route bypass. Cold loading a celebration without summary returns to a safe admissible route rather than exposing catalog/library to a guest.
- [ ] For catalog readers, offer one actual published next book excluding the completed book, plus Save for next time. Use stable catalog ordering initially and honest copy such as Another story; no invented series, reading level, or personalized claim. If no other book is available, offer replay/library without an empty recommendation card.
- [ ] Persist saved-next ID to the current child's checkpoint. Library continuation precedence is unfinished most-recent book, then explicitly saved-next book. If a book was unpublished/deleted, keep the stored position but show an unavailable state and a browse action, not a crash or unrelated substitute.
- [ ] Mount a compact continuation card above/alongside the existing map without blocking map gestures or adding a global library redesign. Resume is a single tap. Scope all reads to the active account/child; selecting another child updates the card immediately.
- [ ] Test accessible finish/overscroll de-duplication, empty next catalog, unavailable saved book, child switching, and next-visit precedence. Keep actual title/page assertions; remove incidental wording/layout tests rather than re-pinning them.
- [ ] Smoke unfinished resume, completed sample return, saved-next reopen, missing book, and child switch. Capture a short return-visit recording.

**Verification:** targeted celebration/checkpoint tests and real return-visit behavior. Account creation alone is not counted as retention.

### Task 7: Verify privacy, measure activation honestly, and release the complete cutover

**Files:** update `bin/symphony-capture-playwright-proof.sh`, `README.md`, and the existing journey documentation `docs/implementation-plans/issue-33-journey-policy.md`; add `docs/implementation-plans/story-first-measurement.md` for metric definitions, approved data boundaries, and results. If session attribution changes are needed, modify `lib/src/features/reader/runtime/reader_analytics_tracker.dart` and `test/features/reader/runtime/reader_session_analytics_test.dart` within this task, preserving historical event semantics. Recording artifacts live under `recordings/`, not source-code assets.

**Consumes:** integrated Tasks 1–6. **Produces:** reviewed proof, an explicit measurement method, and a complete release decision.

- [ ] Record first-interaction timing in supervised, consented usability sessions for old/new journeys using the same device/network/content conditions. Use the spec's event definitions. Record failures/abandonment as outcomes; do not exclude families who do not create accounts.
- [ ] Audit existing authenticated analytics before querying D1/D3/D7. Use parent account as the initial reporting unit, exclude review/test accounts, and anchor at first eligible post-consent meaningful reading interaction. D1 is elapsed UTC hours `[24, 48)`, D3 `[72, 96)`, D7 `[168, 192)`; count at most one qualifying return per account/window. The all-entrant experiment must instead anchor at assigned first entry and retain non-converters in its denominator. Never claim account-only retention proves all-entrant improvement; if current events cannot establish meaningful interaction, report that measurement gap rather than relabel app-open/session-start as reading.
- [ ] Existing `book_completed` fires on last-page visit, including immediate completion of a one-page book; do not use it as the new explicit-finish metric or rename historical data silently. Existing session-end/drop-off includes background/dispose, not necessarily abandonment. Capture account/child at session start so late events cannot be attributed to a newly selected child. Any new post-consent event properties must use a small explicit allowlist, not the existing sanitizer as a general PII filter.
- [ ] Add a regression in the real analytics tracker test: start as child A, change active selection to child B before ending A's session, and assert any permitted trailing event remains attributed to A or is suppressed after sign-out; it must never be attributed to B. Sample mode remains upload-ineligible even after account creation. Run `flutter test test/features/reader/runtime/reader_session_analytics_test.dart test/data/analytics_repository_test.dart` after this edit batch.
- [ ] Document a full-entry experiment as blocked until the privacy/data owner approves collection and the backend supports it. Required server contract: assigned variant and denominator before treatment, deduplicated non-content events, approved identity/retention/deletion policy, and queries including non-converters. No third-party SDK, child name, birth year, transcript, raw audio, or retroactive guest-event upload. Do not ship a no-op event sink and call measurement implemented.
- [ ] Fix proof capture to exercise the changed flow through actual UI. Remove storage-seeding fallbacks from release-proof paths; failures must fail the proof rather than manufacture completion. Update obsolete CTA/goal assumptions. Record guest and reviewer flows separately, and use real test credentials/manual Apple/OTP for normal auth proof.
- [ ] Handle this checkout's existing `web/` directory without overwriting it: create only missing temporary entry files, track exactly what was created, and remove only those files afterward. Do not delete the directory or existing icons. Avoid `flutter create .`; if native-only plugins block browser proof, record the exact blocker and complete native proof while fixing the browser entry needed for these UI paths.
- [ ] Run the repository gate once after the integrated changes:

```bash
./bin/verify.sh
```

Expected: analyzer has zero warnings and all existing/changed behavior tests pass. This is a future execution command, not a claim that this planning session ran tests.

- [ ] Capture ticket-specific UI proof (set `PLAYWRIGHT_PROOF_TICKET` to the actual ticket when assigned). Local artifact names for this feature are:

```text
recordings/story-first-guest-proof.webm
recordings/story-first-parent-auth-proof.webm
recordings/story-first-app-review-proof.webm
recordings/story-first-return-proof.webm
```

No dry-run files or storage-seeded sessions count as proof. Include outgoing-request evidence for the guest session and native audio/permission evidence; browser-only audio is insufficient.

- [ ] Exercise the release matrix below. Update docs with exact commands, successful proof links, and remaining release blockers; preserve user changes and remove only execution-owned throwaway probes after smoke proof.
- [ ] Do not release until every core acceptance row passes and the actual sample/art and safeguards are approved. Roll back the complete entry cutover if a gate/progress/privacy regression appears; never weaken safeguards to preserve conversion.

## Release acceptance matrix

| Scenario | Observable acceptance |
|---|---|
| Fresh guest, offline | Real bundled story opens without sign-in, network content, analytics upload, or microphone prompt. |
| Sound | Silent until explicit play; narration/soundscape work; exit/background stops playback. |
| First value | Measured user-initiated story interaction; proposed median target under 30 seconds, reported honestly. |
| Guest restart | Same logical and visible page restored; completed sample stays completed until replay. |
| Direct protected URL | Cannot bypass parent challenge/year or gain arbitrary catalog access. |
| Gate failure/cancel/lockout | No parent access; checkpoint intact; lockout survives restart as existing behavior requires. |
| Parent sign-in | Apple on iOS and email OTP work; cancellation/errors are recoverable; no redirect double-hop. |
| New child | Nickname + age only, no quiz/default-profile/reading-level chores. |
| Existing account | Explicit child claim; no overwritten progress or cross-child/account leakage. |
| Save failure | Guest record survives; error shown; retry/return possible; no false saved state. |
| Reviewer | Bypass email, gate/year, reduced setup, library; legacy review profile still valid. |
| Completion | Finish button accessible; overscroll alternative emits once; no forced next-story autoplay. |
| Next visit | Resume or saved-next is actionable; missing book has recoverable state. |
| Accessibility | Small viewport, 2x text, keyboard, screen reader, reduced motion all usable. |
| Measurement | No unapproved anonymous analytics; cohort/denominator limitations documented. |

## Explicit extensions, not hidden core deliverables

- **Parent-chosen reminders:** the earlier recommendation was optional. This repo needs a real local-notification/platform scheduling implementation, parent-only time selection, just-in-time permission, denied-permission behavior, timezone/DST handling, reschedule/cancel on setting changes, and native delivery proof. Do not show a notification prompt or promise reminders in the core cutover. Plan that extension after the parent experience is approved.
- **Full entrant-level A/B experiment:** requires the backend/privacy prerequisites in Task 7. Do not add retention lift claims to release notes before those data exist.
- **Cross-device checkpoints, manga/series infrastructure, subscriptions/paywalls, and full library redesign:** separate scopes. The core remains fully usable without them and does not advertise them as implemented.

## Planning-session validation

This document plans future implementation; it does not report passing app tests or a verified visual port. Before execution, verify the referenced existing files still exist, run LSP references for changed exported contracts, and refresh any file changed since this plan was written. Missing approved art/privacy contracts remain explicit prerequisites rather than invented implementation details.
