# Storia Kids — Proof-Test Feature Curation and Tooling Plan

Generated: 2026-04-06

## Goal

Document how Storia Kids can put its best foot forward for school and ABA proof-of-worth conversations by curating the next feature set around measurable pilot outcomes, and identify the libraries/tools needed to implement the highest-priority proof-unlocking features.

---

## Executive Summary

Storia should treat the next product phase as a **proof-test stack**, not just a collection of unrelated features.

The objective is not to build the full long-term institutional platform immediately. The objective is to build the minimum credible system needed to:

1. generate measurable evidence
2. persist that evidence reliably
3. summarize it in a buyer-friendly format

### Core principle

For pilot sales, Storia does not need perfect infrastructure. It needs a **small number of credible metrics** backed by product behavior and simple reporting.

### Recommended proof-test focus
Build a tightly scoped system that can prove:
- usage
- completion
- continuity/resume behavior
- basic learning outcomes
- simple progress summaries for adults

---

## Strategic Framing

### Current reality
The product is currently stronger at creating a delightful child reading experience than at proving institutional value.

### What the next phase should optimize for
- speed to measurable evidence
- low implementation risk
- high buyer relevance
- leverage of current app strengths

### Product strategy implication
Rather than building every desired feature deeply, Storia should launch a curated MVP of proof-unlocking capabilities.

---

## Recommended Curation Strategy

Split the roadmap into two layers:

## Phase 1 — Pilot-proof foundation
Build the minimum infrastructure needed to measure and report:
- reading usage
- completion behavior
- progress persistence
- basic outcomes

## Phase 2 — Buyer-specific differentiation
Layer in more specialized capabilities such as:
- school-specific classroom reporting
- ABA-specific prompt and independence tracking
- caregiver carryover/generalization features

---

## The Five Curated Features to Unlock Proof Fast

These are the best next five features to help Storia put its best foot forward.

## 1. Persistent reading and practice session logging

### MVP scope
Capture only the highest-value fields:
- child/profile id
- session id
- book id
- session start timestamp
- session end timestamp
- duration
- start page
- end page
- completion flag
- resume point
- whether practice mode was used

### Why this is enough for MVP
This unlocks foundational metrics without requiring a full learning-record system.

### Metrics unlocked
- average weekly usage
- sessions per week
- completion rate
- reading continuity
- reading minutes per child

### Suggested implementation approach
Use:
- local cache for immediate resume UX
- backend persistence for canonical reporting

### Recommended tools/libraries
- Existing: **Supabase** for backend storage
- Existing: **shared_preferences** for local resume cache
- Recommended add: **uuid** for session identifiers
- Optional later: **freezed** / **json_serializable** for cleaner typed models

### Suggested backend entities
- `child_profiles`
- `reading_sessions`
- `book_progress`

---

## 2. Analytics taxonomy and instrumentation

### MVP scope
Instrument only a focused set of high-value events:
- `book_opened`
- `reading_session_started`
- `page_turned`
- `reading_session_ended`
- `book_completed`
- `practice_started`
- `practice_completed`
- `comprehension_completed`
- `word_tapped`
- `word_long_pressed`

### Recommended common properties
- child id
- session id
- book id
- page index
- age band
- reading level
- org id
- classroom/provider id
- app version
- platform

### Why this is enough for MVP
This gives Storia enough visibility to analyze engagement, drop-off, and retention without building a large analytics platform internally.

### Metrics unlocked
- engagement rate
- completion rate
- average weekly usage
- drop-off analysis
- return usage / retention

### Tooling decision
There are two realistic MVP paths:

#### Option A — Supabase-first event logging
Store events directly in Supabase tables.

**Pros**
- simplest architecture
- all data in one place
- easy to query alongside progress data

**Cons**
- weak product analytics UX
- more custom work for funnels/cohorts/retention

#### Option B — Analytics tool + Supabase source of truth
Use an external analytics platform for event instrumentation and behavioral analysis, while keeping canonical outcome/progress records in Supabase.

**Recommended choice:** **PostHog**

### Why PostHog is the recommended choice
- startup-friendly
- supports event analytics, funnels, cohorts, and retention
- easier to move quickly than building equivalent analytics workflows manually
- can coexist cleanly with Supabase

### Recommended architecture
- **PostHog** = product analytics and behavior analysis
- **Supabase** = canonical source of truth for progress and reporting data

---

## 3. Resume and completion history

### MVP scope
Add:
- last-read location per child/book
- continue-reading card in library
- completed-books history
- completed date
- read count / completion count

### Why this matters
This improves user experience while also producing measurable continuity and follow-through metrics.

### Metrics unlocked
- books completed per week
- percentage of books completed
- average sessions per book
- return-to-read behavior

### Implementation note
This should be built on top of session/progress persistence, not as a standalone feature.

### Recommended tools/libraries
- Existing: **shared_preferences** for instant local persistence
- Existing: **Supabase** for sync and reporting

No major new dependency is required.

---

## 4. Comprehension checks and saved results

### MVP scope
Do not start with adaptive learning.
Start with:
- 1–3 simple end-of-book questions
- multiple-choice format
- score/result persistence
- trend summaries by child and book

### Why this is the right first move
This is the fastest path to a school-friendly outcome metric that goes beyond raw usage.

### Metrics unlocked
- comprehension completion rate
- average comprehension score
- score trend over time
- basic progress evidence

### Recommended implementation approach
Use a lightweight content model with explicit question definitions and saved attempt records.

### Suggested backend entities
- `book_questions`
- `question_attempts`
- optional derived summaries later

### Recommended tools/libraries
Mostly existing stack is enough:
- Flutter UI
- Supabase persistence

No special quiz library is necessary for MVP.

### Product guidance
Questions should be:
- short
- consistent
- age-appropriate
- easy to score

Avoid trying to prove deep literacy efficacy in the first iteration. The goal is to prove basic understanding and engagement quality.

---

## 5. Adult-facing progress reporting

### MVP scope
Avoid building a huge admin portal first.
Start with:
- one child/client progress summary
- one classroom/clinic summary
- one export/share flow

### Most important metrics to show
For a pilot summary, prioritize:
- active readers
- sessions per week
- average reading minutes
- completion rate
- books completed
- comprehension completion rate
- average comprehension score
- practice sessions completed

### Why this matters
This is the layer that converts internal product data into buyer-facing proof.

### Recommended implementation options

#### Option A — In-app summary screen
Best if parents/staff will already access the app.

#### Option B — Lightweight web dashboard
Better long term for institutions, but more work.

#### Option C — Exportable PDF or CSV summary
Very strong for pilots and much simpler to ship.

### Recommended MVP choice
- in-app summary screen
- CSV export first
- optional PDF summary shortly after

### Recommended tools/libraries
- Recommended add: **fl_chart** for lightweight visual charts
- Recommended add: **csv** for export generation
- Optional add: **pdf** for printable reports
- Optional add: **printing** for share/print flows

### Charting recommendation
Prefer **fl_chart** for MVP due to lighter weight and good-enough visual reporting.

---

## Recommended Proof-Test Stack

## Backend and storage
- **Supabase Postgres** — canonical source of truth
- **Supabase Auth** — already in place
- **Supabase Row Level Security** — important later for org data isolation

## Local persistence
- **shared_preferences** — enough for resume/current progress cache in MVP

### Optional later if local complexity grows
- **Hive**
- **Isar**

For now, `shared_preferences` is sufficient.

## Analytics
- **PostHog** — recommended analytics platform for event tracking, retention, cohorts, and funnels

## Reporting/export
- **fl_chart** — charts
- **csv** — exportable structured summaries
- **pdf** + **printing** — optional printable reports

## Developer-experience helpers
Optional but useful:
- **uuid**
- **freezed**
- **json_serializable**

---

## What Not to Build Yet

To stay focused on proof-testing, defer the following until after the measurement/reporting foundation exists:
- full badge/streak/reward engine
- adaptive quiz engine
- complex therapist prompting taxonomy UI
- large web admin portal
- advanced experimentation platform
- rich caregiver co-read/social layer
- full IEP or ABA goal authoring platform

These may all become valuable later, but they are second-order relative to the immediate need to prove value.

---

## Recommended Roadmap Structure

## Slice 1 — Instrumentation and persistence
Build:
- session logging
- progress persistence
- resume state
- completion tracking
- core event taxonomy

### Outcome
Storia can measure usage and completion reliably.

---

## Slice 2 — Lightweight outcomes
Build:
- simple comprehension checks
- saved results
- practice summaries

### Outcome
Storia can measure basic learning and reading progress signals.

---

## Slice 3 — Reporting
Build:
- child summary
- class/clinic summary
- export flow

### Outcome
Storia can present buyer-friendly proof to administrators, teachers, and clinic leaders.

---

## Schools vs ABA Prioritization

## If prioritizing elementary schools first
Prioritize:
1. session logging
2. completion/resume
3. comprehension checks
4. teacher-facing summary
5. classroom rollup

### Why
Schools are most likely to respond quickly to evidence around:
- engagement
- completion
- comprehension
- simple reporting

---

## If prioritizing ABA clinics first
Prioritize:
1. session logging
2. practice summaries
3. prompt/independence capture
4. caregiver carryover later
5. clinic/client reporting

### Why
ABA buyers care more about:
- independence
- prompt fading
- consistency of implementation
- documented progress

---

## Strategic Recommendation on Market Focus

Given the current state of the app, **schools appear to be the faster proof-test path**.

### Reason
The existing product is closer to proving:
- reading engagement
- completion
- basic comprehension

than it is to proving:
- ABA-grade prompting
- independence progression
- generalization across therapist/caregiver contexts

That does not mean ABA is the wrong market. It means school-facing proof may be faster to operationalize with the current product foundation.

---

## Concrete MVP Recommendation

If Storia wants the strongest short-term proof story, build this stack first:

1. **Supabase tables for sessions, progress, and comprehension**
2. **PostHog event tracking for behavior analytics**
3. **Continue Reading + completion history UX**
4. **Simple end-of-book comprehension checks**
5. **In-app progress summary with CSV export**

### Example proof narrative this enables
> Students averaged X reading sessions per week, completed Y books, spent Z minutes reading, and scored an average of N% on comprehension checks during the pilot.

That is substantially stronger than a qualitative story like “kids liked it.”

---

## Decision Framework for Next Steps

The next product design/architecture discussion should clarify:

1. the exact data model for the five proof-test features
2. whether analytics should be Supabase-only or Supabase + PostHog
3. how to phase delivery across 2–3 implementation slices
4. whether the first external proof target is schools or ABA clinics

---

## Summary

To put its best foot forward, Storia should optimize the next roadmap phase for **proof generation**, not just feature richness.

### Recommended MVP proof-test stack
1. Persistent session/progress logging
2. Analytics taxonomy and instrumentation
3. Resume + completion history
4. Comprehension checks + saved results
5. Adult-facing progress reporting

### Recommended tooling
- **Supabase** for canonical data
- **shared_preferences** for local resume state
- **PostHog** for analytics
- **fl_chart** for charts
- **csv** for exports
- optional: **pdf**, **printing**, **uuid**, **freezed**, **json_serializable**

### Core product principle
A feature that creates value but cannot be measured, persisted, segmented, or reported will underperform in school and clinic sales conversations.
