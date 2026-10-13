# Story-first measurement and release evidence

## Status — 2026-10-06

Technical reader, local checkpoint and protected-entry behavior is implemented against the approved manifest contract. No genuine sample package or approved production visual port is present. Production Try-a-story remains unavailable without a valid bundle. No activation timing, retention lift, or entrant-level experiment result has been measured.

The owner must supply approved page art, narration with word timestamps, soundscape, licensed fonts, content rights and age suitability before genuine-content acceptance or release. Prototype art and technical media fixtures are not that package.

## Reporting units and anchors

### Supervised first-value usability

Use consented sessions, the same device/network/content conditions, and both old/new entry journeys. Start timing at usable first entry. First value is a user-initiated meaningful story interaction: deliberate page navigation, narration/sound activation or intentional engagement with the page. Automatic loading, route entry, session start and account creation do not qualify.

Report the sample size, conditions, median and distribution, failures and abandonment, including families who never create accounts. The proposed under-30-second median is a target, not a result. Do not derive usability timing from the technical fixture recordings.

### Conditional authenticated retention

Initial reporting unit: parent account. Exclude App Review, test and internal accounts. Anchor at the first eligible post-consent meaningful reading interaction, only when an audited event and consent record can establish it. Count at most one qualifying return per account in each elapsed UTC window:

| Metric | Hours after anchor |
|---|---|
| D1 | `[24, 48)` |
| D3 | `[72, 96)` |
| D7 | `[168, 192)` |

A return requires meaningful reading, not app-open, hydration, background/resume, profile creation or passive session start. This cohort is conditional on account creation and eligibility. It cannot demonstrate improvement for all entrants.

### All-entrant experiment — blocked

Privacy/data-owner approval and a real backend contract are prerequisites. Assignment and denominator must exist before treatment and retain non-converters. Required capabilities:

- assigned variant, first-entry anchor and deduplicated participant denominator;
- deduplicated non-content events with a small explicitly approved property allowlist;
- approved identity, retention, deletion and consent policy;
- queries that retain failures and non-converters and separate review/test traffic.

No anonymous third-party SDK, child nickname, birth year, transcript, raw audio or retroactive guest-event upload is added. A no-op event sink would not implement measurement; none is advertised. No experiment queries or lift results exist in this change.

## Existing analytics audit

`reader_analytics_tracker.dart` captures account and child at session start. Permitted trailing events retain that identity; `analytics_repository.dart` suppresses them after sign-out, account change or missing current token. Same-account refreshed credentials are allowed. Selecting child B cannot attribute child A's trailing events to B. A session that starts without complete ownership does not adopt a later login.

Historical meanings are preserved:

- `book_completed` means last-page visit, including a one-page book's initial visit. It is not the new explicit Finish action.
- session end includes background/dispose and is not necessarily abandonment.
- page/session start does not establish user intention or legal consent.

Authentication plus the arithmetic/year access gate is not legal consent. Current events alone do not establish the required post-consent meaningful-reading anchor. D1/D3/D7 queries and claims remain blocked until that gap and the approved consent/eligibility record are resolved.

Sample capability mode never constructs the analytics tracker, network pronunciation/narration services or microphone/speech practice, including after an authenticated child claims the sample. Ownership does not weaken content capabilities.

## Local progress boundaries

Checkpoints are versioned, device-local and separated by guest/account/child. Ordered catalog page IDs define a structural revision, not a server publication revision. Stable page ID restore precedes index clamping. A changed revision conservatively clears completion when the previous terminal structure is no longer proven.

Claiming requires explicit selected-child confirmation. Writes are serialized and copy-first: the guest record survives a failed destination write and a successful claim. Existing child progress requires Keep existing or explicit replacement. Local SharedPreferences does not promise crash-atomic multi-key transactions, cross-isolate coordination or cross-device sync.

Continuation prefers the newest unfinished book, then an explicitly saved-next book. Missing/unpublished content remains unavailable with recovery; it is not silently replaced by another title.

## Observed technical evidence

These artifacts exercise actual Flutter screens using an explicitly labelled technical media fixture and signed-out auth boundary. They are not genuine-story, normal-account-authentication, published-catalog or release proof:

- `recordings/story-first-technical-fixture.webm`: 390×844 browser; actual Play/ambience, page transition, Finish and silent replay. VP9, 34.766 seconds, 816,612 bytes (observed with `ffprobe`).
- `recordings/story-first-technical-parent-review.webm`: actual arithmetic gate, adult year, sign-in→Create account, signup-only `app-review@storia.kids`, nickname/7–9 setup and rendered empty library. No seeded browser storage or direct-route shortcut. Normal auth/backend was not exercised.
- `recordings/story-first-technical-native-reader.png`: actual fresh iPhone 17 Pro simulator reader, with visible fixture disclaimer and no microphone dialog. Native JustAudio reported narration position 84 ms after explicit play; ambience toggled. Background/return and gate cancellation resumed silently on page 2; close/reopen restored page 2; Finish→Read again returned silently to page 1. Input used the running Flutter gesture pipeline, not physical-device touch or a listening-quality review.
- `recordings/story-first-technical-requests.json`: request metadata after fixture entry; 11 same-origin requests and zero external requests. Cold-start intro/theme requests were outside this audit; their runtime Google font use remains a release blocker pending approved local fonts.

The safe harness did not load Supabase or `.env`; the `.env` asset was temporarily excluded during technical builds/tests. The temporary harness/web entry were removed afterward, existing web icons retained, and SDK-owned iOS deployment/checksum changes reverted. Production startup configuration is intentionally unchanged: shipping the complete `.env` asset remains unsafe until the client-safe configuration prerequisite is resolved.

Browser automation emitted a Flutter SDK keyboard assertion (`Invalid modifier location: -, 1`) while synthesizing a hyphen in the reviewer address. The route completed; this is an automation/SDK limitation, not evidence of an error-free normal-keyboard/authentication release run.

## Verification result — 2026-10-06

- `./bin/verify.sh`, with a process-only Flutter wrapper appending `--no-pub` and `.env` excluded from technical asset packaging: architecture guardrails and extension checks passed; analyzer reported zero issues; Flutter tests reported **509 passed, 2 failed**. The repository gate is not green.
- Remaining failures in unchanged `test/features/library/book_preview_overlay_test.dart`: `library map round trip keeps the human artwork explanation` (missing badge/explanation) and `parent narration keeps artwork info reachable on a small viewport` (24px horizontal overflow at 280×320 and 2× text). The corresponding artwork-provenance/preview implementation is outside this entry plan; tests were not deleted or re-pinned. Do not infer these failures were present before the work: no earlier full-suite baseline proves that.
- Targeted sample/gate tests: 9 passed, covering silent entry, native-service exclusion, parent cancellation, physical/logical page restore and retained 0.3/0.2 mix.
- Targeted auth-round-trip, picker and remaining reader celebration visibility tests: 8 passed after test-owned entry notifiers/timers were disposed before widget invariants. Removed obsolete coordinator-forwarding/default/reset-to-zero assertions instead of re-pinning them to the new restore contract.
- `bash -n` capture script/harness passed. `bash test/bin/symphony_proof_capture_fallback_test.sh` and `bash test/bin/pi_symphony_bash32_compat_test.sh` passed, including reviewer entry when the sample replaces Parent setup. These are harness checks, not production capture proof.
- Temporary harness/web entry removed, own debug services and simulator helpers stopped, execution-created simulator deleted, existing simulator/web icons preserved, SDK-owned deployment/checksum upgrades reverted, and the original `.env` asset declaration restored. No secret values were inspected or copied into evidence.


## Required release proof

Use `PLAYWRIGHT_PROOF_TICKET` for the actual ticket and separate `PLAYWRIGHT_PROOF_FLOW=guest|app-review`. The capture script drives UI, fails on missing essential stages, and keeps failed recordings outside successful discovery. `PLAYWRIGHT_PROOF_CAPTURE_DRY_RUN=1` writes `*-capture-harness.txt`, never a proof WebM. It creates/removes only missing temporary web entry files, preserving existing files/icons.

Before release: genuine fresh/offline guest and return recordings; cold-start outgoing-request audit; native narration/soundscape and permission evidence using genuine assets; Apple on iOS and email OTP with real test credentials; actual selected-child save/conflict/failure and next-visit behavior with published books; small/tablet/2× text/keyboard/screen-reader/reduced-motion proof against the approved design; repository gate and uploaded ticket-specific artifacts.

No uploaded artifact link, consented usability result, genuine sample approval, full accessibility matrix, real normal-auth proof or all-entrant backend contract is supplied by the technical fixture evidence. Do not release this entry cutover until those prerequisites and the plan's acceptance matrix pass.
