# Story-first onboarding design

Status: proposed implementation contract for the user's requested plan; visual approval and release prerequisites remain explicit gates. No production implementation is authorized by this document alone.

## Goal

Let a new family experience a real Loratone story before account creation, then make parent setup, saving, and the next visit coherent. Optimize meaningful reading return, not quiz completion or maximum screen time.

## Sources and precedence

- User conversation: retention guidance favors tangible value before setup; user requested an implementation plan after the recommendation.
- `.wolf/cerebrum.md`: latest entry-flow preferences override the previous recommendation to retain paper/sketch styling.
- `design/entry-flow/DIRECTION.md`: retain the Webtoon-for-kids positioning and required safeguards; the rejected stage/library-card/music-box explorations are not options to revive. The external 17-screen exploration is not an approved implementation specification.
- Existing routing authority: `lib/src/routing/journey/journey_policy.dart`.

## Global constraints

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

## Experience

### New visitor

1. Intro shows approved story artwork, a concise product promise, primary **Try a story**, and secondary **Parent sign in**. No feature carousel, quiz, permission prompt, autoplay audio, price, or fabricated trust claim.
2. Try a story opens one bundled, complete, short sample through the existing reader rendering/runtime. The sample is free to replay. A cover/loading state is real artwork, never a blank Rive region.
3. Reading is silent until the user explicitly starts sound. Offer a clearly labeled play/pause/mute action; the sample demonstrates narration and soundscape with local assets. Contextual guidance matches the existing vertical reader: **Swipe up for the next page**, not a fictional tap-to-turn control.
4. A natural pause or completion offers **Save my place** / **Ask a grown-up**, plus **Not now** or **Read again**. No automatic auth interruption mid-page.
5. A parent enters the existing challenge and adult-year check, then signs in or creates an account. Reuse the gate widgets and lockout; do not fork the challenge implementation. Preserve draft reading position while leaving the reader.
6. An account with no child profile goes directly to a compact nickname + age-range setup, not an empty profile picker followed by another form. Existing accounts with multiple profiles keep explicit child selection; never choose a child silently to receive guest history.
7. After explicit save confirmation, return to the same sample and position. A completed sample remains completed; do not relaunch it as unread. The library's continuation card leads back to the sample or the selected saved book.

### Returning family

- Unfinished sample on the device: intro offers **Continue story**, with replay available separately.
- Authenticated selected child: enter library normally; a continuation card shows the current child's unfinished book or their saved next read. Other children's positions never appear.
- Completed story: keep celebration, offer one real published next-book choice and a way to save it for next time. Do not label arbitrary books as a series sequel or personalized recommendation.
- End-of-book remains accessible without an overscroll-only gesture: show a completion action at the last page, with accessible labeling and no double celebration.
- No forced next-book autoplay, guilt streak, or reminder permission during intro.

### App Review

Keep the documented bypass email and a usable reviewer route through safeguards and reduced child setup into the library. Guest mode must not rely on review storage. Existing persisted review profiles must load after removing the goal requirement. Preserve the reviewer birth-year flow even when reviewer activation resets its state; avoid a duplicate challenge in a continuous, already verified parent session.

## State and boundaries

Separate three concerns instead of expanding review state into a general guest account:

1. **Entry state:** local hydration readiness, temporary parent-area authorization, auth intent, validated resume destination, and adult-year check. Parent authorization is short lived and cannot be restored by changing a URL; relock on background/cold launch. Only explicit parent-flow transitions carry it through an auth callback. Birth year is a year-only age check; do not describe it as exact age verification.
2. **Reading checkpoint:** small on-device record scoped to guest or an authenticated account + child. Fields: schema version, content ID/revision, page ID/index, completion status, update time, and optional saved-next book ID. No child name, email, audio, transcript, or per-word behavioral trail.
3. **Reader capabilities:** sample versus catalog session, chosen at the route/data boundary and propagated to the runtime dependencies. Disallowed capabilities must not initialize their services; hiding controls is insufficient.

Guest progress is saved locally without account creation. After sign-in and explicit child selection, **Save this story for [nickname]?** claims the checkpoint to that child on this device. Keep guest data until the destination write succeeds; repeat confirmation cannot duplicate or regress progress. Existing child progress wins conflicts unless the parent explicitly chooses the guest position. Do not upload old guest analytics on claim. Logout removes visibility of the previous account's continuation data.

Initial release promises **saved on this device** only, with page-level resume rather than exact audio-offset resume. The sibling `../storia` backend already contains authenticated progress/session/continue-reading APIs, but Flutter does not integrate them; deployment, sample numeric-book mapping, and multi-device conflict semantics are unverified. Cross-device progress requires that integration and is not implied by account creation. Reuse the existing backend contracts if cloud sync is separately approved; do not build competing endpoints.

## Sample/content contract

Use one editor-approved, complete short picture-book experience supported by the existing reader. Do not build a manga renderer or a recommendation engine as part of entry onboarding. Cover-driven presentation should reflect the product's picture-book + kids' manga positioning without claiming an unavailable episode catalog.

The content owner supplies approved title/author/rights, stable sample ID and revision, complete page art and text, local narration plus aligned timestamps, soundscape, cover/fallback, font licenses, and documented age suitability. All sample references resolve to bundled assets; no hosted CDN, generated cover, or placeholder is acceptable at release. Content must satisfy the no-animal/no-mascot constraint. This checkout's direction notes explicitly identify missing approved cover/panel artwork; the implementer must not fabricate that prerequisite.

Asset image/audio support must work on web and iOS with the existing rendering/session engines. Do not pass asset paths into APIs that assume network URLs. The sample must load from a cold launch with network disabled; audit startup/font requests as well as reader requests. No weakening database RLS to expose the regular catalog.

## Design acceptance

Approve a linked prototype of intro, sample reader, completion, parent gate, birth year, auth + OTP, compact profile form, claim confirmation, and returning continuation states. Include keyboard, small-screen, loading/failure, and reduced-motion variants.

Use warm color, vivid approved covers, rounded shapes, refined spacing, soft depth, legible type, and motion caused by interaction. No fake founders, prices, testimonials, guarantees, or unverified privacy claims from earlier mockups. Existing account creation and account recovery remain readable and accessible.

Viewport checks: 320x568, 390x844, 430x932, and tablet; text scale 1.0 and 2.0. Primary action remains reachable, scrolling is intentional, keyboard never hides submit/error recovery, and touch targets are at least 48 logical pixels. Reduced motion eliminates nonessential movement without hiding content.

## Measurement and rollout

Hypothesis: story-first increases meaningful D7 reading return per new entrant, even if immediate account creation decreases. Proposed UX target: first meaningful story interaction within 30 seconds; establish baseline rather than promising a retention uplift.

Definitions:
- First meaningful interaction: user-initiated page advance or explicit narration start while the page is visible; not intro tap or automatic render.
- Completion: explicit finish after reaching the last page; emit once per reading attempt.
- Existing `book_completed` analytics means last-page visit, not this explicit completion definition. Keep historical reports separate; the existing wall-clock/all-pages celebration summary is not verified engaged reading time.
- Meaningful return: reading interaction on D1/D3/D7, not app-open alone; choose and document fixed elapsed-day windows before analysis.
- Guardrails: reader crashes/audio failures, lost or cross-child progress, gate bypass, auth failure, consent violations.

This repository's authenticated reading analytics must not be repurposed as an anonymous onboarding telemetry channel. First validate the experience with supervised, consented usability sessions and account-scoped measures available under the existing privacy policy. A full entrant-level A/B test is separately gated on approved collection, backend ingestion, retention/deletion rules, randomization, and correct denominators; converted-account-only results cannot establish all-entrant retention. No new analytics SDK.

Parent-scheduled local reminders are an optional extension after the core flow; there is no required intro notification prompt. They need an approved parent UX and real platform scheduling implementation. Cross-device sync, manga/series backend, monetization changes, and whole-library redesign are separate projects, not hidden dependencies or unfinished parts of this cutover.

## Delivery boundary

Ship the core only when real sample assets, route/privacy protections, local resume/claim, redesigned entry screens, next-visit continuation, and real device/browser proof all pass. Do not ship a Try a story CTA that redirects to auth or loads fabricated content. Keep the existing public flow until the integrated replacement meets these gates; no permanent duplicate onboarding system.
