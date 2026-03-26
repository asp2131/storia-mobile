## Problem

Reader runtime behavior is currently coordinated across multiple shallow modules and UI code:

- `lib/src/features/reader/reader_screen.dart`
- `lib/src/audio/audio_engine.dart`
- `lib/src/features/reader/reader_audio_state.dart`
- `lib/src/features/reader/reader_practice_notifier.dart`
- `lib/src/features/reader/page_renderer.dart`

Architectural friction:

- The `ReaderScreen` orchestrates page changes, async audio transitions, speech practice lifecycle, and celebration timing directly.
- Integration risk exists in seam behavior (rapid page flips + async audio loading + speech callbacks).
- Understanding behavior requires bouncing across UI/state/engine files.
- The module boundaries are shallow: callers must know orchestration details instead of relying on one deep boundary.

This makes the codebase harder to navigate, harder to test at behavior boundaries, and more fragile under feature changes.

## Proposed Interface

Adopt a deep module with a minimal public interface and a ports/adapters internal architecture.

### Interface signature

```dart
sealed class ReaderIntent {
  const ReaderIntent();
}

final class ReaderStart extends ReaderIntent {
  const ReaderStart({required this.book, this.initialPageIndex = 0});
  final Book book;
  final int initialPageIndex;
}

final class ReaderGoToPage extends ReaderIntent {
  const ReaderGoToPage(this.pageIndex);
  final int pageIndex;
}

final class ReaderToggleNarration extends ReaderIntent {
  const ReaderToggleNarration();
}

final class ReaderToggleSoundscape extends ReaderIntent {
  const ReaderToggleSoundscape();
}

final class ReaderTogglePractice extends ReaderIntent {
  const ReaderTogglePractice();
}

final class ReaderAckCelebration extends ReaderIntent {
  const ReaderAckCelebration();
}

@immutable
class ReaderViewState {
  final bool isReady;
  final int activePageIndex;
  final Duration narrationPosition;
  final bool isNarrationPlaying;
  final bool isSoundscapePlaying;
  final double narrationVolume;
  final double soundscapeVolume;
  final bool isPracticeMode;
  final bool isListening;
  final Set<int> spokenWordIndices;
  final bool showCelebration;
  // ...copyWith + defaults
}

abstract interface class ReaderSession {
  Stream<ReaderViewState> get states;
  Future<void> dispatch(ReaderIntent intent);
  Future<void> dispose();
}
```

### Usage example

```dart
final session = ref.read(readerSessionProvider);

@override
void initState() {
  super.initState();
  _sub = session.states.listen((s) => setState(() => _state = s));
}

Future<void> _onBookLoaded(Book book) async {
  await session.dispatch(ReaderStart(book: book));
}

Future<void> _onPageChanged(int index) async {
  await session.dispatch(ReaderGoToPage(index));
}

Future<void> _onPracticeTap() =>
    session.dispatch(const ReaderTogglePractice());
```

### Complexity hidden internally

- Deterministic transition ordering and cancellation/race handling.
- Page transition choreography for narration/soundscape continuity.
- Speech listener lifecycle, partial/final result handling, and celebration timing.
- Derived control state consistency (play/pause/listening/practice toggles).
- Plugin-specific details and retry/error normalization.

## Dependency Strategy

**Category:** True external (Mock)

- External/plugin boundaries:
  - Audio player/session stack (`just_audio`, `audio_session`)
  - Speech recognition (`speech_to_text`)
- Introduce ports at the deep-module boundary:
  - `AudioPort`
  - `SpeechPracticePort`
  - `Clock/SchedulerPort` (for celebration timeout and deterministic testing)
- Production uses plugin adapters.
- Tests use in-memory fake adapters and deterministic scheduler.

## Testing Strategy

### New boundary tests to write

At `ReaderSession` interface level:

1. **Start flow**: `ReaderStart` initializes state, loads initial page audio, computes page words.
2. **Rapid page flips**: only last `ReaderGoToPage` wins; stale async work is ignored.
3. **Narration/soundscape toggles**: toggles reflect in state and invoke correct audio port calls.
4. **Practice lifecycle**: toggle on initializes speech; start/stop transitions update listening state.
5. **Speech results**: partial/final results update `spokenWordIndices` correctly.
6. **Celebration behavior**: final recognized words trigger `showCelebration`; timeout/ack clears it.
7. **Page reset behavior**: changing page resets spoken-word highlights/listening state predictably.
8. **Error resilience**: plugin errors convert to stable state transitions without UI crashes.

### Old tests to delete

As boundary coverage is added, delete shallow/internal tests that assert implementation details in:

- `audio_engine` internals (ordering details)
- `reader_audio_state_notifier` stream plumbing specifics
- `reader_practice_notifier` private transition detail tests

Retain only tests that verify externally visible behavior through `ReaderSession`.

### Test environment needs

- In-memory fake `AudioPort` + `SpeechPracticePort`
- Deterministic fake scheduler/clock for timeout and async timing
- Fixture pages/books for narration timestamp and overlay token scenarios

## Implementation Recommendations

- **Module ownership**: One `ReaderSession` module owns runtime orchestration state and intent handling.
- **Hide**:
  - Async sequencing/cancellation tokens
  - Speech and audio plugin quirks
  - Cross-feature state coupling details
- **Expose**:
  - Minimal intent API (`dispatch`)
  - Single observable state stream (`states`)
- **Caller migration**:
  1. Move orchestration logic out of `ReaderScreen` into `ReaderSessionImpl`.
  2. Replace direct calls to audio/practice notifiers with `dispatch` intents.
  3. Keep rendering widgets (`PageRenderer`, controls) fed by `ReaderViewState` only.
  4. Incrementally delete old provider wiring once parity tests pass.

This refactor deepens the module boundary so tests target behavior where risk actually lives: the orchestration seam.
