# Reading Engagement Plan for Kids

Generated: 2026-03-02

## Goal
Improve the reading experience for kids (ages 5-12) by increasing engagement and comprehension while keeping safety and wellbeing guardrails in place.

---

## Current Product Snapshot (Codebase Audit)

### Core flow
- Library to Reader journey is defined in `lib/src/routing/app_router.dart`.
- Book browsing and discovery are in `lib/src/features/library/library_screen.dart`.
- The main reading experience is in `lib/src/features/reader/reader_screen.dart`.

### Existing strengths
- Immersive page reading with vertical paging and clean chrome controls.
- Narration and ambient soundscape controls via `lib/src/audio/audio_engine.dart`.
- Word-level highlight sync from narration timestamps in:
  - `lib/src/features/reader/overlay/text_overlay_utils.dart`
  - `lib/src/features/reader/overlay/overlay_text_layer.dart`
  - `lib/src/features/reader/overlay/overlay_text_element.dart`
- Data and content loading are cleanly modeled in:
  - `lib/src/data/book_repository.dart`
  - `lib/src/data/models.dart`

### Main gaps
- No persistent progress/resume experience.
- No rewards, milestones, or child-facing completion loop.
- No child profile personalization (age/level/avatar-based experience).
- `onWordTap` interaction path exists but is not fully leveraged in reader UX.
- No comprehension checks or recap flow.
- No analytics taxonomy for engagement experimentation.

---

## Feature Concepts (Evidence-Informed)

### Motivation
1. Choice boards (topic, length, mood)
2. Mastery badges for reading skills
3. Session goals (time or vocabulary target)

### Comprehension
4. Tap word support (pronounce, kid-friendly meaning, image cue)
5. Micro check-ins every few pages (prediction/inference)
6. End-of-story recap cards

### Social / Co-read
7. Co-read mode with parent prompts
8. Invite-only reading clubs (private, moderated)

### Creativity
9. Alternate ending studio (draw/write/voice)
10. Story-to-make offline missions

### Top 5 MVP (impact vs effort)
1. Session goals
2. Tap word support
3. Co-read mode prompts
4. Micro check-ins
5. Choice boards

---

## Quick Wins vs Deeper Bets

### Quick wins (near-term)
- Persist reading resume state (`bookId`, `pageIndex`, optional timestamp).
- Add a prominent "Continue Reading" card in library.
- Wire `onWordTap` to a simple support sheet (replay + definition).
- Add last-page completion celebration and a next-book CTA.
- Persist narration/soundscape preferences.
- Apply lifecycle and loop robustness updates from `specs/audio-lifecycle-audit-fixes.md`.

### Deeper bets (mid-term)
- Backend-backed per-child progress and cross-device sync.
- Child profile + personalization system (age/level/recommendation).
- Configurable engagement engine (goals, badges, milestones).
- Adaptive comprehension and review loops.
- Experimentation platform integration and decision dashboarding.

---

## Experimentation Framework

### North-star metric
- Weekly Engaged Readers (WER): unique kids with >=3 sessions/week and >=20 minutes/week.

### Primary and secondary outcomes
- Primary: average weekly reading minutes per active reader.
- Secondary: D1/D7 retention, sessions/week, story completion rate, books completed/week.

### Guardrails
- Learning quality: comprehension performance, appropriate-level rereads.
- Safety/trust: report and moderation incident rates.
- Product health: crash-free sessions, API reliability.
- Wellbeing: excessive session duration and off-hours usage signals.

### Core event taxonomy (minimum)
- `app_opened`
- `home_viewed`
- `book_impression`
- `book_opened`
- `reading_session_started`
- `page_turned`
- `reading_session_ended`
- `book_completed`
- `quiz_started` / `quiz_completed`
- `reward_earned`
- `streak_updated`
- `notification_sent` / `notification_opened`

Recommended common properties:
- `user_id`, `child_id`, `session_id`, `timestamp`, `platform`, `app_version`, `experiment_id`, `variant`, `age_band`, `reading_level`.

---

## Initial A/B Test Backlog (6)
1. Personalized home rail ordering
2. Continue-reading module prominence
3. Streak framing and parent-friendly reminders
4. Completion screen with one-tap next book
5. Read-aloud default for early readers segment
6. Reminder timing optimization

Each test should include:
- Hypothesis
- Primary success metric
- Guardrail checks
- Rollout stages (10% -> 50% -> 100%)

---

## 8-Week Rollout Outline

- Week 1: Metric definitions, event schema, tracking plan.
- Week 2: FE/BE instrumentation implementation.
- Week 3: Data QA and baseline dashboards.
- Week 4: Launch tests #1 and #2 at 10% traffic.
- Week 5: Evaluate/ramp winners; launch test #3.
- Week 6: Launch tests #4 and #5.
- Week 7: Launch test #6 and cross-test interaction review.
- Week 8: Final readout, rollout decisions, next-quarter backlog.

---

## Suggested First Implementation Slice (1-2 weeks)
1. Add local resume persistence and continue-reading UI.
2. Wire word tap support in reader overlay interactions.
3. Add basic completion celebration + next-book CTA.
4. Instrument session/completion events and ship first dashboard.
