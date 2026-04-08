# Storia Kids — Proof of Worth Gap Analysis

Generated: 2026-04-06

## Goal

Document current product gaps that limit Storia Kids' ability to demonstrate measurable value to elementary schools and ABA clinics, and identify the shortest-path feature investments that would unlock stronger proof-of-worth metrics.

---

## Executive Summary

Storia Kids already has strong child-facing experience foundations:
- playful library discovery
- immersive reader UX
- narration + soundscapes
- word-level highlighting
- tap/long-press word support
- early read-aloud practice mode
- celebration moments

However, the product is currently much weaker in the systems required to **prove value to institutions**:
- persistent progress tracking
- event analytics
- measurable outcomes data
- adult-facing reporting
- workflow features that support staff efficiency

### Core conclusion

**Storia is currently better at creating value than proving value.**

That means the biggest product gap is not delight or content presentation, but the missing measurement and reporting stack needed for school and clinic buyers.

---

## Strongest Proof-of-Worth Metrics We Want to Support

These are the most persuasive metrics for school and ABA buyers:

1. % of students/clients making measurable progress
2. Rate of goal mastery
3. Increase in independent responding
4. Reduction in prompts needed
5. Engagement rate / completion rate
6. Average weekly usage
7. Teacher/therapist prep time saved
8. Caregiver/teacher satisfaction
9. Generalization across settings
10. Retention / renewal / expansion

---

## Current Product Strengths

### Child-facing strengths observed in code/specs
- Engaging adventure-map library flow
- Reader runtime with narration and soundscape controls
- Word-level text highlighting via narration timestamps
- Tap/long-press word support through word TTS service
- Practice mode using speech-to-text
- End-of-session celebration feedback
- Basic onboarding profile for review flow

These are meaningful UX strengths, but they do not yet convert into strong institutional reporting.

---

## Major Product Gaps Limiting Proof of Worth

## 1. No persistent learning/progress data

### Observed gap
The app reads book/content data, but there is no evident persisted model for:
- reading sessions
- page progress
- resume state
- completion history
- practice attempt history
- longitudinal skill development

### Why it matters
Without persisted progress data, Storia cannot credibly show:
- measurable progress over time
- books completed per week
- average reading minutes
- return usage patterns
- practice improvement by child

### Metrics blocked
- % making measurable progress
- rate of goal mastery
- engagement/completion rate
- average weekly usage
- retention over time

---

## 2. No analytics/event instrumentation layer

### Observed gap
There is no visible analytics implementation or event taxonomy for core product actions such as:
- book opened
- reading session started
- page turned
- reading session ended
- book completed
- practice started/completed
- word tapped
- reward earned

The reading engagement plan explicitly identifies analytics taxonomy as a gap.

### Why it matters
Even if the product is being used successfully, Storia cannot yet convert that into buyer-ready evidence.

### Metrics blocked
- engagement rate
- completion rate
- average weekly usage
- D1/D7 retention
- weekly engaged readers
- drop-off analysis

---

## 3. No real comprehension measurement

### Observed gap
The current app supports reading interaction but does not show a live comprehension layer such as:
- micro check-ins
- recap cards
- quiz data model
- answer capture and scoring
- saved comprehension trend history

### Why it matters
Schools and clinics need evidence that children are not just opening books, but understanding them.

### Metrics blocked
- measurable progress
- learning quality
- goal mastery
- comprehension improvement over time

---

## 4. Practice mode exists, but not yet as a reportable fluency system

### Observed gap
The current read-aloud practice implementation tracks session-local state like:
- listening active/inactive
- spoken word indices
- temporary celebration

But it does not appear to persist or report:
- words correct per minute
- accuracy rate
- attempt count
- trend over time
- page/book-level fluency summaries

### Why it matters
This could become a core differentiator for proving reading progress, but today it is not yet institution-ready.

### Metrics blocked
- measurable progress
- rate of goal mastery
- independent responding improvement
- reading fluency trend

---

## 5. No prompt-level / independence model

### Observed gap
There is no structured model for:
- independent response
- verbal prompt
- gestural prompt
- model prompt
- therapist-assisted performance

### Why it matters
For ABA clinics especially, the ability to show prompt fading and independence growth is central to proving clinical value.

### Metrics blocked
- increase in independent responding
- reduction in prompts needed
- treatment-goal progress
- consistency across providers

---

## 6. No child profile / learner model for institutional reporting

### Observed gap
Existing onboarding/profile data appears consumer/review oriented rather than educational or clinical.

Missing learner metadata includes:
- reading level
n- classroom/caseload grouping
- assigned goals
- support needs/accommodations
- staff/provider linkage
- multi-child household or org support structures

### Why it matters
Without a stronger learner model, Storia cannot segment outcomes in ways that matter to schools and clinics.

### Metrics blocked
- progress by subgroup
- goal mastery by domain
- adoption by classroom/provider
- clinic/classroom level outcomes

---

## 7. No adult-facing reporting layer

### Observed gap
There is no visible reporting experience for:
- teacher dashboard
- clinic dashboard
- learner/client progress summaries
- exportable reports
- classroom/caseload rollups
- provider adoption reports

### Why it matters
Institutional buyers need dashboards and exports, not just a strong child UX.

### Metrics blocked
- measurable progress summaries
- org-level usage
- teacher/therapist efficiency proof
- renewal / expansion narratives

---

## 8. No adult workflow features that clearly save time

### Observed gap
The current app is child-first, but does not appear to support adult workflows such as:
- assigning books or activities
- auto-recommended next content by skill
- roster management
- exportable session summaries
- progress-note support
- streamlined follow-up workflows

### Why it matters
One of the easiest institutional proof points is time saved for teachers and clinicians.

### Metrics blocked
- prep time saved
- documentation time saved
- consistency across staff
- throughput per staff member

---

## 9. No caregiver/home carryover system

### Observed gap
There is no visible carryover system for:
- home practice assignment
- co-read prompts
- caregiver confirmation/completion
- home vs school/clinic usage comparison
- generalization tracking across settings

### Why it matters
Generalization and carryover are especially persuasive for schools and ABA clinics.

### Metrics blocked
- generalization across settings
- caregiver follow-through
- maintenance over time

---

## 10. Weak completion/mastery loop

### Observed gap
There are celebratory touches, but no full mastery loop including:
- streaks
- badges
- goals
- milestone states
- history of completed books
- next-best-action guidance

### Why it matters
These systems support engagement, persistence, and repeat use—important leading indicators for proof-of-worth.

### Metrics blocked
- engagement rate
- completion rate
- average weekly usage
- retention

---

## Prioritized Gaps by Importance

## Tier 1 — Must-have to prove value
1. Persistent session/progress data
2. Analytics/event taxonomy
3. Outcome measurement (comprehension + fluency)
4. Adult-facing reporting

## Tier 2 — Needed to win schools and ABA
5. Goal model (reading/SEL/therapy target alignment)
6. Prompting + independence data
7. Multi-child / classroom / clinic structures

## Tier 3 — Multipliers
8. Adult workflow/assignment features
9. Caregiver carryover / co-read mode
10. Rewards / streaks / goals

---

## Best Next 5 Features to Unlock Proof Fast

These are the five shortest-path product investments most likely to unlock proof-of-worth testing.

## 1. Persistent reading and practice session logging

### What to capture
- session start/end timestamps
- duration
- book id
- page range
- completion status
- resume point
- practice attempts/results
- child id / profile id

### Why it matters
This is the foundation for nearly every buyer-facing metric.

### Unlocks
- average weekly usage
- completion rate
- progress over time
- reading frequency
- resume/continuity UX

---

## 2. Analytics taxonomy + instrumentation

### Core events
- `book_opened`
- `reading_session_started`
- `page_turned`
- `reading_session_ended`
- `book_completed`
- `practice_started`
- `practice_completed`
- `word_tapped`
- `word_long_pressed`

### Recommended dimensions
- child id
- session id
- book id
- page index
- age band
- reading level
- org id / classroom / provider id
- app version
- platform

### Why it matters
Enables dashboards, baseline measurement, experimentation, and retention analysis.

### Unlocks
- engagement rate
- completion rate
- return usage
- drop-off analysis

---

## 3. Resume + completion history

### What to add
- persistent last-read location per child/book
- continue-reading surfaces in library
- completion history timeline
- completed-books count and recency

### Why it matters
Improves UX and creates measurable evidence of continuity and follow-through.

### Unlocks
- books completed/week
- % completing books
- average sessions/book
- return-to-read behavior

---

## 4. Comprehension checks + saved results

### What to add
- end-of-story recap cards
- 1–3 micro-check-ins per story
- score/result persistence
- trend summary by child/book/skill domain

### Why it matters
This is the cleanest path to showing learning quality rather than raw consumption.

### Unlocks
- measurable progress
- comprehension trend
- goal mastery signals
- school-facing outcome proof

---

## 5. Adult-facing progress reporting

### What to add
- child/client progress view
- classroom/caseload summary
- exportable report or shareable summary
- usage + outcomes rollup

### Why it matters
This turns internal product data into something institutions can actually evaluate and buy against.

### Unlocks
- org-level proof
- stakeholder communication
- pilot evaluation
- renewal justification

---

## What Storia Likely Cannot Yet Prove Strongly

Based on the current codebase, Storia likely cannot yet strongly prove:
- % of students/clients making measurable progress
- rate of goal mastery
- increase in independent responding
- reduction in prompts needed
- average weekly usage at buyer-grade confidence
- completion rate at buyer-grade confidence
- teacher/therapist time saved
- generalization across settings
- org-level ROI

This is not because the product lacks value. It is because the current measurement, persistence, and reporting layers are underbuilt relative to institutional buying needs.

---

## Product Strategy Implication

### Current state
Strong child experience, weak proof system.

### Needed shift
The next product phase should prioritize:
1. instrumentation
2. persistence
3. outcomes capture
4. adult reporting

### Principle
If a feature creates value but cannot be measured, segmented, persisted, or reported, it will underperform in school/clinic sales conversations.

---

## Recommended Discussion Topics for Next Step

1. How to sequence the five proof-unlocking features into a realistic roadmap
2. Which features should be optimized first for schools vs ABA clinics
3. What data model changes are required in Supabase
4. What analytics/reporting stack to use for MVP vs scale
5. What libraries/tools to adopt for event tracking, storage, dashboards, and exports

---

## Summary

To put its best foot forward with elementary schools and ABA clinics, Storia should invest next in the infrastructure and workflows that transform a good child reading experience into measurable institutional evidence.

### Best next five features
1. Persistent session/progress logging
2. Analytics taxonomy + instrumentation
3. Resume + completion history
4. Comprehension checks + saved results
5. Adult-facing progress reporting

These five features offer the shortest path from “kids enjoy this” to “we can prove this works.”
