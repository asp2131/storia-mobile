# Reading Progress Dashboard Plan

Generated: 2026-09-25

## Goal

Give every adult around a young reader — and the reader themselves — an honest,
encouraging view of reading activity:

- **Children** see what they've accomplished (celebratory, never comparative).
- **Parents** see habits, favorite books, and growing independence.
- **Teachers** see who is reading, who has stalled, and which books land.
- **School leaders** see aggregate adoption and engagement to justify and steer
  the program.

Related: `specs/reading-engagement-plan.md` (north-star metric, event taxonomy).

---

## Current State (Codebase Audit)

### Instrumentation already exists

`ReaderAnalyticsTracker` (`lib/src/features/reader/runtime/reader_analytics_tracker.dart`)
emits child-scoped events through `AnalyticsRepository`
(`lib/src/data/analytics_repository.dart`) to `POST /api/analytics/events`, which
persists to the backend `mobile_analytics_events` table.

| Event | Key metadata |
|---|---|
| `reading_session_started` / `reading_session_ended` / `reading_session_drop_off` | `durationMs`, `completed`, `viewedPageCount`, `lastPageIndex`, `pageCount`, `reason` |
| `book_started` / `book_completed` | `bookId`, `pageCount`, `initialPageIndex` |
| `page_viewed` / `page_interacted` | `pageIndex`, `interactionType`, `source` |
| `narration_played` / `soundscape_played` | `pageIndex` (user-initiated plays only) |
| `word_audio_played` / `phoneme_audio_played` | `wordIndex`, `outcome` |
| `speech_attempt_started` / `speech_attempt_completed` | `attemptId`, `matchedWordCount`, `hadSpeech`, `reason` |

`AnalyticsMetadataSanitizer` already strips raw audio and transcripts. Keep it that way.

### Gaps

1. **Write-only pipeline.** No read/aggregate API exists. Backend lives in the
   separate storia.kids web repo.
2. **No role above parent.** `ChildProfile` (`lib/src/features/child/domain/child_profile.dart`)
   has `ageBand` + `readingLevel`, but there is no teacher, classroom, or school
   entity.
3. **Metadata holes:**
   - Word events carry `wordIndex` only — can't build a "tricky words" list.
   - Narration has a play event but no stop/duration — can't compute listen time.
   - No `app_version` / `platform` common properties.
   - No reading `mode` (read-to-me vs. read-myself) on sessions.
   - Non-numeric `bookId` values only survive inside `properties`.

---

## Metrics by Audience

### Child — "My Reading"

| Metric | Source |
|---|---|
| Books finished shelf (covers) | `book_completed` |
| Reading streak (days) | distinct days with `reading_session_ended` ≥ 2 min |
| Minutes this week (watercolor meter toward goal) | sum `durationMs` |
| Favorite story ("read 4 times!") | favorite-book score (below) |
| Words practiced | `word_audio_played` + `speech_attempt_completed` |

Rules: no rankings, no peer comparison, no red/negative states.

### Parent — "Reading Progress" (behind `ParentalGate`)

| Metric | Source / definition |
|---|---|
| Minutes per day (7/30-day bar chart) | sum `durationMs` by local day |
| Sessions, books started vs. finished | session + book events |
| Most-loved books | favorite-book score |
| Narration & soundscape usage | plays per session; % of pages viewed with narration on |
| Word help trend | word taps/long-presses per 100 pages viewed — falling = growing independence |
| Read-aloud practice | attempts; avg `matchedWordCount` / page word count |
| Where they stop | page-index histogram of `reading_session_drop_off` |
| Time-of-day pattern | session start hour distribution (wellbeing guardrail) |

### Teacher — Classroom view

- Roster heatmap: minutes per child per day.
- "Needs a nudge": children with no session in 7 days.
- Book completion rate across the class.
- Independence trend: share of reading with narration off, over the term.
- Read-aloud participation.

### School leader — Aggregate view

- **Weekly Engaged Readers** (≥3 sessions and ≥20 min/week) — the north-star from
  `reading-engagement-plan.md`.
- Adoption: active children / rostered children, by grade and class.
- Total minutes by grade/class; week-over-week trend.
- Top titles and genres school-wide.
- Narration/soundscape usage share (evidence for the audio investment).
- Reading-level movement (start-of-term vs. now).
- Exportable CSV/PDF for board reporting.
- **Aggregates only.** Suppress any cohort with fewer than 5 children.

### Favorite-book score

Opens alone overweight accidental taps. Use:

```
score = 2 × completions + 1 × distinct_days_opened + minutes_read / 10
```

Tunable server-side; the client only renders the ranked list.

---

## Architecture

### Backend (storia.kids repo)

1. **Rollup table** `child_daily_reading_stats`
   (`child_profile_id, day, minutes, sessions, pages_viewed, books_started,
   books_completed, narration_plays, soundscape_plays, word_help_count,
   speech_attempts, speech_matched_words`), populated by nightly job or insert
   trigger from `mobile_analytics_events`.
2. **Per-book rollup** `child_book_stats`
   (`child_profile_id, book_id, opens, completions, minutes, last_read_at`).
3. **Endpoints:**
   - `GET /api/progress/child/:childProfileId?range=7d|30d|term`
   - `GET /api/progress/classroom/:classroomId?range=...` (phase 5)
   - `GET /api/progress/school/:schoolId?range=...` (phase 6, aggregate only)
4. Authorization: parent owns child; teacher linked via classroom membership;
   leader linked via school admin role.

Never aggregate raw events on device — too slow, and web dashboards need the
same numbers.

### Mobile (this repo)

Follow existing conventions (Riverpod 2.x, no codegen, design tokens):

| Piece | Location |
|---|---|
| `ProgressRepository` + hand-written models (`ChildProgressSummary`, `DailyReadingStat`, `BookEngagement`) | `lib/src/data/progress_repository.dart`, `lib/src/data/progress_models.dart` |
| `childProgressProvider` (`FutureProvider.family<ChildProgressSummary, ProgressQuery>`) | `lib/src/features/progress/data/progress_providers.dart` |
| Parent screen | `lib/src/features/progress/presentation/parent_progress_screen.dart` |
| Child screen | `lib/src/features/progress/presentation/my_reading_screen.dart` |
| Route + parental gate | `lib/src/routing/app_router.dart` (`JourneyRoutes.progress`, `JourneyRoutes.myReading`) |
| Widgets | reuse `SketchCard`, `SketchButton`, `WatercolorScaffold`; colors from `StoriaColors` |

Entry points: library chrome button (child view), Settings → "Reading progress"
behind `ParentalGate` (parent view), and a "See your shelf" CTA on the book
celebration screen.

### Tracker additions (ship first — history can't be backfilled)

- `word_audio_played` / `phoneme_audio_played`: add `word` (lowercased text).
- New `narration_stopped` event with `listenedMs`.
- Common properties: `appVersion`, `platform`.
- Session events: `mode` = `read_to_me` | `read_myself`.

---

## Privacy & Consent

- Three consent contexts: parent-only (COPPA), classroom (FERPA + parent
  opt-in), school aggregate.
- Classroom sharing requires an explicit parent action (join code) per child;
  revocable from Settings.
- Leader views are aggregate-only with small-cohort suppression (n < 5).
- No raw audio or transcripts stored, ever (existing sanitizer stays).
- Data retention window documented and enforced server-side.

---

## Phased Delivery

| Phase | Scope | Repo |
|---|---|---|
| 1 | Tracker metadata additions + tests | mobile |
| 2 | Rollup tables + `/api/progress/child` | backend |
| 3 | Parent progress screen | mobile |
| 4 | Child "My Reading" screen + celebration CTA | mobile |
| 5 | Classroom model, join codes, teacher dashboard (web first) | backend + web |
| 6 | School-leader aggregates + CSV/PDF export | backend + web |

## Open Questions

1. Teacher/leader tiers: mobile, web, or both?
2. Backend repo access for phases 2+.
3. Favorite-book score weights — validate with real data after phase 2.
4. Weekly minutes goal: fixed default (e.g. 60 min) or parent-set?
