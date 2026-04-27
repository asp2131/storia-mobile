# Mobile Word Pronunciation QA Checklist

Status: Draft  
Date: 2026-04-25  
Scope: `storia-mobile`  
Source: Ticket #18 in `specs/mobile-word-pronunciation-team-plan.md`

## Goal

Use this checklist to manually verify mobile word pronunciation before release. The tester should be able to run these checks from an installed iOS or Android build without reading code.

Phase-1 expected behavior:

- **Tap** on a word is unchanged: it plays the existing whole-word help path.
- **Long-press** on a word is manifest-first: use recorded pronunciation audio when available, then fall back to existing TTS when unavailable or failing.
- Pronunciation should never crash the reader, block page navigation, overlap indefinitely, or leave narration/practice mode stuck.

## Test record

Fill this out once per test run.

| Field | Value |
|---|---|
| Tester | |
| Date | |
| Build/version | |
| Platform | iOS / Android |
| Device model | |
| OS version | |
| Audio route | Speaker / headphones / Bluetooth |
| Network | Wi-Fi / cellular / slow / offline |
| Test account | |
| Books used | |

## Required test content

Use prepared QA books or fixtures that cover these cases. If a prepared book is unavailable, mark the affected cases **Blocked** and note the missing fixture.

| Fixture | Required content |
|---|---|
| Supported pronunciation book | At least one visible word with `breakdown + full-word` pronunciation audio. |
| Full-word-only book or page | At least one visible word with only full-word pronunciation audio. |
| Unsupported word/page | A visible word with no pronunciation entry. |
| No-manifest book | A book with no pronunciation rows/support. |
| Failure fixture | Manifest fetch failure and/or audio URL failure, provided by QA environment, proxy, or bad-asset test book. |
| Practice-mode content | A book/page where practice/listening mode can be started. |

## Result key

- **Pass:** observed result matches the expected result.
- **Fail:** observed result differs, crashes, hangs, overlaps audio unexpectedly, or leaves UI/audio state stuck.
- **Blocked:** tester cannot run the case because required fixture, device, account, or network setup is unavailable.

For every **Fail**, capture:

1. Device + OS + build.
2. Book/page/word used.
3. Steps to reproduce.
4. What was heard and what was visible.
5. Screenshot or screen recording when possible.

---

## 1. Core interaction

### QA-MWP-01 — Tap behavior is unchanged

**Preconditions**
- Open any readable book page with interactive words.
- Narration is stopped or paused.

**Steps**
1. Tap a word once.
2. Wait for playback to finish.
3. Tap another word once.

**Pass if**
- Each tap follows the existing whole-word help behavior.
- No breakdown/segment-by-segment pronunciation plays from a tap.
- The word highlight/transient state clears after playback.
- The reader remains scrollable/pageable and responsive.

**Fail if**
- Tap triggers the new long-press breakdown behavior.
- Tap and long-press audio both play for one tap.
- Highlight or loading state remains stuck.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-02 — Long-press uses manifest-backed breakdown audio

**Preconditions**
- Open the supported pronunciation book.
- Navigate to a word known to have `breakdown + full-word` audio.

**Steps**
1. Long-press the supported word until the long-press action triggers.
2. Release your finger after the trigger.
3. Listen to the full pronunciation sequence.

**Pass if**
- The word does not also trigger normal tap playback for the same gesture.
- Breakdown audio plays first.
- Full-word audio plays after the breakdown when provided.
- Playback occurs once and then stops.
- The reader remains responsive after playback.

**Fail if**
- No pronunciation plays when the fixture is known to be supported.
- Tap-style whole-word TTS plays instead of the manifest-backed audio.
- Breakdown and full-word clips overlap each other.
- The same long-press causes duplicate playback.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-03 — Long-press full-word-only manifest entry

**Preconditions**
- Open the full-word-only book/page.
- Navigate to a word known to have only full-word audio.

**Steps**
1. Long-press the full-word-only word.
2. Listen until playback ends.

**Pass if**
- The manifest full-word clip plays.
- The app does not show an error or fall into silence because the breakdown clip is missing.
- Playback ends cleanly and the reader remains usable.

**Fail if**
- Missing breakdown audio blocks all playback.
- UI state remains highlighted/loading after playback.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-04 — Unsupported word falls back safely

**Preconditions**
- Open a page with a visible word that has no pronunciation manifest entry.

**Steps**
1. Long-press the unsupported word.
2. Listen for fallback playback.
3. Repeat with punctuation-adjacent words if available, such as `Hello.`, `Don't`, or `high-tech`.

**Pass if**
- The app falls back to the existing TTS/help path.
- No error dialog, crash, or frozen reader occurs.
- Punctuation around the word does not cause a crash.

**Fail if**
- Nothing happens and the reader appears stuck.
- Unsupported words throw visible errors or break future word interactions.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-05 — Short press/release does not accidentally long-press

**Preconditions**
- Open the supported pronunciation book.

**Steps**
1. Touch a supported word briefly and release before the long-press threshold.
2. Repeat 5 times at normal reading speed.

**Pass if**
- Brief touches behave like normal taps only.
- Breakdown audio does not trigger unless the touch is held long enough.

**Fail if**
- Breakdown audio triggers from normal taps or very short touches.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 2. Manifest network handling

### QA-MWP-06 — Manifest present and cached in the reader session

**Preconditions**
- Network is online.
- Open the supported pronunciation book.

**Steps**
1. Wait for the page to settle after opening the reader.
2. Long-press a supported word.
3. Navigate away from the page and back within the same reader session, if possible.
4. Long-press the same word again.

**Pass if**
- The first long-press uses manifest-backed audio.
- The second long-press also works without visible extra loading or errors.
- The reader does not become slower or repeatedly show loading/error states for the same book.

**Fail if**
- The first interaction works but later interactions in the same session fail unexpectedly.
- Repeated interactions appear to retry/fail noisily or freeze the reader.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-07 — Manifest missing by contract

**Preconditions**
- Open a no-manifest book.
- Network is online.

**Steps**
1. Tap several words.
2. Long-press several words.
3. Navigate between pages and repeat.

**Pass if**
- Tap behavior remains unchanged.
- Long-press falls back to existing TTS/help behavior.
- No pronunciation-only loading state blocks reading.
- Page navigation remains stable.

**Fail if**
- Reader shows manifest-related errors to the user.
- Long-press becomes inert or leaves a stuck state.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-08 — Manifest fetch failure

**Preconditions**
- Use the failure fixture, a QA environment that forces manifest fetch failure, or a proxy/network setup that blocks the manifest request.
- Start from a fresh app session when possible.

**Steps**
1. Open the affected book.
2. Long-press a word that would normally be supported.
3. Repeat once after 5-10 seconds.

**Pass if**
- The reader remains usable.
- The app falls back to existing TTS/help behavior or exits cleanly without user-facing crash/error.
- Failure does not leave permanent loading/highlight state.
- Retrying does not create rapid repeated error popups or repeated visible stalls.

**Fail if**
- Reader crashes, freezes, or blocks interaction while fetching.
- Long-press remains stuck in a loading/highlight state.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-09 — Slow manifest load

**Preconditions**
- Enable slow network using device tools, network link conditioner, proxy throttling, or QA network profile.
- Start from a fresh app session.

**Steps**
1. Open the supported pronunciation book.
2. Immediately long-press a supported word before the page has had much time to preload data.
3. Continue interacting with the page while the request is pending.
4. After the network response completes, long-press the word again.

**Pass if**
- The reader remains responsive while manifest loading is slow.
- First interaction either resolves to manifest-backed audio or falls back cleanly.
- Later interaction works once data is available.
- No duplicate audio, duplicate visible loading states, or stuck highlights remain.

**Fail if**
- Slow manifest load blocks reading or page navigation.
- Multiple long-presses during load create overlapping audio or a stuck state.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-10 — Slow or failing audio asset

**Preconditions**
- Use a fixture where pronunciation audio is slow, returns `404`/`403`, or is blocked by QA proxy.

**Steps**
1. Long-press the affected supported word.
2. Wait through the slow/failing audio attempt.
3. Try a normal tap on the same or nearby word.

**Pass if**
- Reader remains usable while audio is slow.
- Failed audio exits cleanly and attempts the safe fallback when available.
- Normal word interactions still work afterward.

**Fail if**
- The pronunciation player waits forever.
- Future taps/long-presses stop working after the failed asset.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 3. Narration coexistence

### QA-MWP-11 — Narration active pauses and resumes

**Preconditions**
- Open the supported pronunciation book.
- Start narration and confirm it is actively playing.

**Steps**
1. While narration is playing, long-press a supported word.
2. Listen through pronunciation playback.
3. Observe narration after pronunciation ends.

**Pass if**
- Narration pauses before pronunciation audio begins.
- Pronunciation plays once.
- Narration resumes after pronunciation finishes.
- Narration resumes from the expected reading state, not from the beginning or a wrong page.

**Fail if**
- Narration and pronunciation overlap unexpectedly.
- Narration does not resume even though it was playing before and the tester did not pause it.
- Narration resumes at the wrong page/position.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-12 — Narration paused stays paused

**Preconditions**
- Open the supported pronunciation book.
- Ensure narration is loaded but paused/stopped by the user.

**Steps**
1. Long-press a supported word.
2. Wait for pronunciation playback to finish.

**Pass if**
- Pronunciation plays.
- Narration does not auto-start after pronunciation ends.

**Fail if**
- Narration starts after pronunciation even though it was paused before the interaction.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-13 — User pause/stop during pronunciation prevents auto-resume

**Preconditions**
- Open the supported pronunciation book.
- Start narration.

**Steps**
1. Long-press a supported word while narration is playing.
2. While pronunciation is playing, tap the narration pause/stop control or otherwise indicate narration should remain paused.
3. Wait for pronunciation to finish.

**Pass if**
- The app respects the latest user intent.
- Narration does not auto-resume after the tester paused/stopped it during pronunciation.
- Controls remain responsive.

**Fail if**
- Narration restarts after the tester explicitly paused/stopped it.
- The narration control becomes out of sync with actual audio.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-14 — Pronunciation while narration is buffering or ending

**Preconditions**
- Open a book where narration can be started.
- Use a slower network or long narration file if available.

**Steps**
1. Start narration.
2. Trigger a long-press while narration is starting/buffering, or just as narration is ending.
3. Observe audio and controls for 10 seconds after pronunciation ends.

**Pass if**
- The app does not misclassify narration state in a way that causes unexpected auto-start or permanent pause.
- No overlapping long-lived audio remains.
- Controls match actual playback state.

**Fail if**
- Narration unexpectedly starts when it should not, or fails to resume when it clearly should.
- Audio/control state becomes inconsistent.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 4. Repeated rapid interactions

### QA-MWP-15 — Rapid long-presses on the same word

**Preconditions**
- Open the supported pronunciation book.

**Steps**
1. Long-press the same supported word 3-5 times in quick succession.
2. Continue until at least one pronunciation is interrupted by a newer request.

**Pass if**
- Playback follows cancel-and-replace behavior: only the latest surviving pronunciation continues.
- Audio does not overlap indefinitely.
- Highlight/transient state belongs to the latest interaction and clears afterward.
- Reader remains responsive.

**Fail if**
- Multiple pronunciations overlap.
- Old requests clear or corrupt the visible state for the latest request.
- The reader becomes stuck after rapid interactions.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-16 — Rapid long-presses across different words

**Preconditions**
- Open a page with at least two supported words visible.

**Steps**
1. Long-press word A.
2. Before playback finishes, long-press word B.
3. Repeat with word C if available.

**Pass if**
- Final audible result corresponds to the latest long-pressed word.
- Prior pronunciation playback is cancelled or safely ignored.
- No stale highlight remains on earlier words.
- Narration resume behavior, if narration was active, reflects only the latest surviving interaction.

**Fail if**
- Earlier word audio continues over later word audio.
- Earlier word highlight/loading persists after later interaction.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-17 — Mixed tap and long-press rapid interactions

**Preconditions**
- Open any page with interactive words.

**Steps**
1. Tap word A.
2. Immediately long-press word B.
3. Immediately tap word C.
4. Repeat once with narration active, if possible.

**Pass if**
- The app remains deterministic and responsive.
- No audio overlaps indefinitely.
- The final control/highlight state clears cleanly.

**Fail if**
- Interactions create stuck audio, stuck highlight, or unresponsive controls.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 5. Page navigation during pronunciation

### QA-MWP-18 — Navigate page during pronunciation playback

**Preconditions**
- Open the supported pronunciation book.
- Use a word with a long enough pronunciation clip to allow navigation while it plays.

**Steps**
1. Long-press the supported word.
2. Before playback finishes, navigate to the next page.
3. Wait 5 seconds on the destination page.
4. Interact with a word on the destination page.

**Pass if**
- Pronunciation from the prior page stops or is safely ignored after navigation.
- No prior-page highlight or state appears on the destination page.
- Destination page word interactions work normally.
- Narration does not auto-resume unexpectedly because of the prior page interaction.

**Fail if**
- Prior-page pronunciation keeps playing on the new page.
- Destination page becomes unstable or unresponsive.
- Old request changes UI/audio state after navigation.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-19 — Navigate while manifest/audio is still loading

**Preconditions**
- Use slow network or a slow audio fixture.

**Steps**
1. Open the supported pronunciation book.
2. Long-press a supported word while manifest/audio is still loading.
3. Immediately navigate to another page.
4. Wait for the pending request to finish or time out.

**Pass if**
- Pending work is cancelled or ignored for the old page.
- No audio from the old page starts after navigation completes.
- The new page remains stable.

**Fail if**
- Audio starts late for a word on the previous page.
- Old-page loading/highlight state appears after navigation.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 6. iOS device path

Run this section on at least one physical iOS device. Simulator-only coverage is not sufficient for audio sign-off.

### QA-MWP-20 — iOS baseline pronunciation path

**Preconditions**
- Physical iPhone or iPad.
- Normal network.
- Device volume audible; silent mode/audio route noted in test record.

**Steps**
1. Open the supported pronunciation book.
2. Run QA-MWP-01 through QA-MWP-04 on iOS.
3. Start narration and run QA-MWP-11 and QA-MWP-12.

**Pass if**
- Tap, long-press, fallback, and narration coexistence match expected behavior on iOS.
- Audio routes through the selected output.
- No iOS-specific permission, audio-session, or silent-mode issue blocks playback unexpectedly.

**Fail if**
- Pronunciation audio is silent while other app audio works.
- iOS audio session prevents narration from resuming or stopping correctly.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-21 — iOS interruption sanity check

**Preconditions**
- Physical iOS device.
- Supported pronunciation book open.

**Steps**
1. Start pronunciation playback.
2. Change audio route if available, such as speaker to headphones/Bluetooth.
3. Background and foreground the app once.
4. Return to the reader and interact with another word.

**Pass if**
- App recovers to a usable state.
- No stale pronunciation audio or controls remain after returning.
- New word interactions work normally.

**Fail if**
- App loses audio permanently until restart.
- Reader controls remain stuck after route/background changes.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 7. Android device path

Run this section on at least one physical Android device. Emulator-only coverage is not sufficient for audio sign-off.

### QA-MWP-22 — Android baseline pronunciation path

**Preconditions**
- Physical Android phone or tablet.
- Normal network.
- Device volume audible; audio route noted in test record.

**Steps**
1. Open the supported pronunciation book.
2. Run QA-MWP-01 through QA-MWP-04 on Android.
3. Start narration and run QA-MWP-11 and QA-MWP-12.

**Pass if**
- Tap, long-press, fallback, and narration coexistence match expected behavior on Android.
- Audio routes through the selected output.
- No Android-specific audio focus issue causes unexpected overlap or silence.

**Fail if**
- Android audio focus causes narration/pronunciation to overlap indefinitely or become silent.
- Reader controls no longer match actual audio state.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-23 — Android interruption sanity check

**Preconditions**
- Physical Android device.
- Supported pronunciation book open.

**Steps**
1. Start pronunciation playback.
2. Lock and unlock the device, or background and foreground the app.
3. If available, switch between speaker and Bluetooth/headphones.
4. Return to the reader and interact with another word.

**Pass if**
- App returns to a usable reader state.
- No stale pronunciation playback persists unexpectedly.
- New tap and long-press interactions work normally.

**Fail if**
- Audio focus is lost permanently until app restart.
- Old pronunciation audio or highlight state remains stuck.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 8. Offline mode

### QA-MWP-24 — Open reader offline with no cached manifest

**Preconditions**
- Start from a fresh install/session if possible, or clear app data/cache.
- Enable airplane mode before opening the supported pronunciation book.

**Steps**
1. Open the app and navigate to a book/page available for offline reading.
2. Long-press several words.
3. Tap several words.

**Pass if**
- Reader does not crash because manifest cannot be fetched.
- Long-press falls back safely where possible.
- Tap behavior remains unchanged.
- If offline reading itself is unavailable, the app shows the normal offline-reading UX rather than a pronunciation-specific failure.

**Fail if**
- Pronunciation manifest failure breaks the reader page.
- A word remains stuck highlighted/loading after offline interaction.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-25 — Go offline after manifest was loaded

**Preconditions**
- Network online.
- Open supported pronunciation book and successfully long-press one supported word.

**Steps**
1. Enable airplane mode without closing the app.
2. Long-press the same supported word again.
3. Long-press a different supported word.
4. Long-press an unsupported word.

**Pass if**
- Cached manifest data, if available, does not break when offline.
- Missing/uncached audio falls back or exits cleanly.
- Unsupported words still use safe fallback behavior.
- No retry storm or repeated user-facing network errors occur.

**Fail if**
- Going offline after preload makes the reader unusable.
- Audio failure waits forever or blocks future interactions.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-26 — Recover after offline failure

**Preconditions**
- Complete QA-MWP-24 or QA-MWP-25.

**Steps**
1. Turn network back on.
2. Return to the same reader page or reopen the book.
3. Long-press a supported word.

**Pass if**
- The app recovers without reinstalling or force-closing.
- Supported words can use manifest-backed pronunciation again once network/data is available.

**Fail if**
- Prior offline failure permanently disables pronunciation for the session/book.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## 9. Practice mode interactions

### QA-MWP-27 — Pronunciation while practice/listening mode is active

**Preconditions**
- Open practice/listening mode for a book/page with supported pronunciation words.
- Confirm the microphone/listening state is active if that is part of the mode.

**Steps**
1. Long-press a supported word while practice/listening mode is active.
2. Listen for pronunciation playback.
3. Observe practice/listening state after playback completes.

**Pass if**
- Practice/listening input pauses or yields while pronunciation plays, if needed.
- Pronunciation audio is not recorded/interpreted as the learner's answer.
- Practice/listening resumes only when appropriate and does not get stuck off/on.
- Standard reader behavior outside practice mode is unchanged.

**Fail if**
- Microphone/listening remains incorrectly active during pronunciation and captures app audio.
- Practice mode cannot continue after pronunciation.
- Pronunciation changes standard reader behavior after leaving practice mode.

Result: Pass / Fail / Blocked  
Notes/evidence:

### QA-MWP-28 — User exits practice mode during pronunciation

**Preconditions**
- Practice/listening mode is active.
- Supported pronunciation word is visible.

**Steps**
1. Long-press a supported word.
2. While pronunciation is playing, exit practice mode or navigate back to standard reading mode.
3. Interact with a word in standard reader mode.

**Pass if**
- In-flight pronunciation is stopped or safely ignored when mode changes.
- Practice state does not leak into standard reading mode.
- Standard tap and long-press interactions still work.

**Fail if**
- Pronunciation continues in a confusing way after leaving practice mode.
- Practice/listening controls remain stuck or affect standard reader interactions.

Result: Pass / Fail / Blocked  
Notes/evidence:

---

## Release sign-off summary

| Area | Required result | Actual result | Notes |
|---|---|---|---|
| Core interaction | All core cases pass or approved exceptions documented | | |
| Manifest/network handling | Present, missing, failure, and slow cases pass | | |
| Narration coexistence | All narration transition cases pass | | |
| Rapid interactions | Same-word, cross-word, mixed interactions pass | | |
| Page navigation | Playback/loading cancellation cases pass | | |
| iOS device | Physical-device path passes | | |
| Android device | Physical-device path passes | | |
| Offline mode | Offline and recovery cases pass | | |
| Practice mode | Practice interaction cases pass, or feature not applicable documented | | |

## Final verdict

Verdict: Pass / Fail / Blocked

Open issues:

| # | Severity | Area | Summary | Repro case |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
