# Gen-UI Reader Activity Cards and Parent Insights Design

Date: 2026-05-15
Status: Approved for ticketing

## Summary

Build a shared, schema-driven Storia Gen-UI card system for two surfaces:

1. **Reader Activity Cards** shown after meaningful story pages.
2. **Parent Insight Cards** shown first in the existing Settings/Profile area.

The system should render only whitelisted Storia-native widgets. It should not allow arbitrary Flutter widget construction, arbitrary navigation, or remote code execution. The first version should use local/mock schema data behind a content-source interface so backend or LLM-generated schemas can be added later without rewriting the renderer.

## Goals

- Add page-attached reader prompts that support comprehension, character empathy, reader feeling check-ins, personal connection questions, and visual choice interactions.
- Make every reader prompt skippable and adaptive in frequency.
- Use visually-first answer choices for children, avoiding A/B/C/D letter choices.
- Summarize reader interactions and emotional check-ins for parents in supportive, aggregate insight cards.
- Include harder feelings such as worried, scared, sad, frustrated, or confused in parent insights when relevant, without diagnosis or alarmist language.
- Keep implementation backend-ready while starting with local/mock schemas.

## Non-goals

- No backend persistence in the initial version.
- No live LLM-generated child-facing content in the initial version.
- No arbitrary schema-to-widget rendering.
- No changes to auth, parental gate, subscriptions, or core reader audio controls.
- No raw emotional-response timeline in parent settings.

## Proposed Architecture

Create a shared feature module:

```text
lib/src/features/gen_ui/
  domain/
    gen_ui_card.dart
    gen_ui_choice.dart
    gen_ui_response.dart
  data/
    gen_ui_content_source.dart
    mock_gen_ui_content_source.dart
    gen_ui_response_store.dart
  presentation/
    gen_ui_card_renderer.dart
    reader_activity_card.dart
    parent_insight_card.dart
```

Core content-source interface:

```dart
abstract interface class GenUiContentSource {
  Future<List<ReaderActivityCardSchema>> getReaderCards({
    required String bookId,
    required String pageId,
    required int pageIndex,
  });

  Future<List<ParentInsightCardSchema>> getParentInsightCards({
    required String childProfileId,
  });
}
```

The first implementation should provide `MockGenUiContentSource`, then later implementations can fetch approved schemas from Supabase or another backend source.

## Reader Activity Cards

Reader cards appear after pages where a prompt is meaningful. They should be displayed as a lightweight interruption between page reading and continuing the story.

Initial variants:

1. `true_false`
2. `picture_choice`
3. `icon_choice`
4. `character_empathy`
5. `reader_feeling_checkin`
6. `personal_connection`

Behavior rules:

- Every card is skippable.
- Skipping is neutral and should not be treated as failure.
- Choices are visually-first and may be visual-only.
- Do not use A/B/C/D letter labels.
- Comprehension cards may have correctness.
- Emotional cards must never be graded.
- Visual-only choices must still include metadata for accessibility, analytics, debugging, parent summaries, and future localization.

Example reader schema:

```json
{
  "id": "page-3-feeling",
  "surface": "reader",
  "variant": "reader_feeling_checkin",
  "pageId": "page-3",
  "title": "How do you feel right now?",
  "displayMode": "visual_only",
  "choices": [
    {
      "id": "happy",
      "label": "Happy",
      "icon": "😊",
      "accessibilityLabel": "Happy"
    },
    {
      "id": "worried",
      "label": "Worried",
      "icon": "😟",
      "accessibilityLabel": "Worried"
    }
  ],
  "skippable": true
}
```

## Adaptive Prompt Frequency

Reader prompts should start at a moderate frequency and adapt locally:

- If the child answers prompts, continue normal frequency.
- If the child skips repeatedly, reduce frequency.
- If the child engages with emotion prompts but skips quizzes, prefer emotion prompts.
- If the child skips all prompts, preserve mostly uninterrupted reading.

The initial policy can be simple and local. It should be implemented as a small, testable unit such as `AdaptivePromptPolicy`, separate from the card renderer.

## Parent Insight Cards

Parent insight cards live first in the existing Settings/Profile area near the active reader/profile section.

Initial variants:

1. `weekly_summary`
2. `emotion_pattern`
3. `comprehension_growth`
4. `story_interest`
5. `conversation_starter`

Insights summarize:

- comprehension patterns
- answered/skipped prompt trends
- story interests
- emotion check-in patterns
- harder feelings like worried, scared, sad, frustrated, confused, lonely, or nervous
- suggested parent conversation prompts

Tone and privacy rules:

- Aggregate patterns; do not show raw logs by default.
- Avoid diagnosis or mental-health interpretation.
- Avoid alarmist language.
- Pair harder-feeling insights with supportive conversation prompts.
- Do not show timestamp-by-timestamp or page-by-page emotional surveillance.
- Future backend persistence should include a parent setting for whether emotion check-ins appear in parent insights.

Example parent schema:

```json
{
  "id": "emotion-pattern-weekly",
  "surface": "parent",
  "variant": "emotion_pattern",
  "title": "Storm scenes brought up worried feelings",
  "body": "Avery chose worried during a few suspenseful story moments this week.",
  "suggestion": "Try asking: What helped the character feel brave?",
  "tone": "supportive"
}
```

## Data Flow

Initial flow:

```text
Reader page changes
  ↓
ReaderActivityController asks GenUiContentSource for page cards
  ↓
AdaptivePromptPolicy decides whether to show one
  ↓
ReaderActivityCard renders
  ↓
Child answers or skips
  ↓
GenUiResponseStore records local response
  ↓
Settings reads ParentInsightCards
```

Initial storage can be in-memory for the first prototype or `shared_preferences` if the implementation needs persistence across app restarts. Backend persistence is out of scope for the first ticket.

## Error Handling

- Invalid reader schemas should be skipped and must never block reading.
- Invalid parent insight schemas should be hidden or replaced with a soft fallback.
- Development builds may log schema validation failures.
- No-card states should be quiet in the reader and should show an empty-state message in Settings only if useful.

## Accessibility

- Visual-only choices must include `accessibilityLabel`.
- Touch targets should be large and child-friendly.
- Cards should use existing Storia theme tokens and shared widgets.
- Emotional choices should use clear semantics without implying correctness.

## Relevant Existing Areas

- Reader route: `/reader/:bookId`
- Reader screen: `lib/src/features/reader/reader_screen.dart`
- Reader controller: `lib/src/features/reader/application/reader_experience_controller.dart`
- Settings route: `/settings`
- Settings screen: `lib/src/features/settings/settings_screen.dart`
- Theme/widgets: `lib/src/core/theme/`, `lib/src/core/widgets/`
- Provider patterns: existing Riverpod 2 handwritten providers; do not introduce codegen.

## Acceptance Criteria

- A shared Gen-UI domain model and renderer support whitelisted reader and parent card schemas.
- Reader activity cards can be surfaced after meaningful pages using local/mock schema data.
- Reader choices can be visual-only, but include labels and accessibility labels in schema/model data.
- Reader activity cards are skippable.
- Emotional cards cannot be graded.
- Adaptive prompt frequency reduces prompts after repeated skips.
- Parent insight cards render in Settings/Profile area for the active child profile.
- Parent emotion insights include both positive/neutral and harder feelings using supportive aggregate language.
- Invalid schemas fail gracefully and never block reading.
- Tests cover schema validation, adaptive policy, emotional-card grading restrictions, visual-choice accessibility metadata, reader answer/skip behavior, and parent insight rendering.

## Validation Expectations

- `flutter analyze`
- targeted Flutter tests for the new Gen-UI feature module
- `./bin/verify.sh` before handoff when practical
- Playwright/WebM proof for UI behavior because both reader and Settings surfaces are browser-verifiable

## Risks and Follow-up Decisions

- Backend schema storage, moderation, and versioning are intentionally deferred.
- Privacy settings for parent insight inclusion of emotional check-ins should be added before backend persistence.
- Remote images for choice cards should be reviewed separately for caching, safety, and offline behavior.
- Live LLM-generated child-facing prompts require a stricter safety and approval pipeline before use.
