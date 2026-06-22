# AudioEngine Interface Extraction + SoLoud Migration Path

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `AudioEngine` into two caller-facing interfaces (`PageAudio` + `PronunciationPlayer`) backed by a `RawPlayer` abstraction, enabling testability of the 312-line audio state machine and a clean migration path to `flutter_soloud`.

**Architecture:** Two small interfaces (`PageAudio` for narration/soundscape, `PronunciationPlayer` for word pronunciation) sit above `AudioEngine`, which holds all orchestration logic. A `RawPlayer` abstraction below `AudioEngine` decouples the orchestration from the audio backend (`just_audio` today, `flutter_soloud` tomorrow). The `AudioSnapshot` value type collapses three observation streams into one.

**Tech Stack:** Flutter, Dart, `just_audio`, `audio_session`, Riverpod 2.x (no codegen), `package:test`

**RFC:** https://github.com/asp2131/storia-mobile/issues/34

---

## File Structure

### New files (create)

| File | Responsibility |
|------|---------------|
| `lib/src/audio/raw_player.dart` | `RawPlayer` abstract class — backend-agnostic player interface |
| `lib/src/audio/just_audio_player.dart` | `JustAudioPlayer implements RawPlayer` — wraps `just_audio` `AudioPlayer` |
| `lib/src/audio/page_audio.dart` | `PageAudio` interface + `AudioSnapshot` value type |
| `lib/src/audio/pronunciation_player.dart` | `PronunciationPlayer` interface |

### Modified files

| File | Change |
|------|--------|
| `lib/src/audio/audio_engine.dart` | Refactor to use `RawPlayer` factory, implement `PageAudio` + `PronunciationPlayer`, add `duckForPractice`/`restoreFromPractice`, add `AudioSnapshot` stream |
| `lib/src/audio/audio_providers.dart` | Provide `PageAudio` + `PronunciationPlayer` via `RawPlayerFactory` |
| `lib/src/features/reader/runtime/reader_session_impl.dart` | Switch from `AudioPort` to `PageAudio`, use `AudioSnapshot` stream, replace practice ducking with `duckForPractice`/`restoreFromPractice` |
| `lib/src/features/reader/runtime/providers/reader_session_provider.dart` | Wire `PageAudio` instead of `AudioEngineAudioPort` |
| `lib/src/features/reader/runtime/providers/reader_word_help_provider.dart` | Wire `PronunciationPlayer` instead of `AudioEnginePronunciationPort` |
| `lib/src/features/reader/runtime/word_help/reader_word_help.dart` | Replace `PronunciationAudioPort` with `PronunciationPlayer` typedef |
| `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart` | Use `play` instead of `playSequence` |
| `lib/src/features/reader/runtime/word_help/reader_word_help_adapters.dart` | Remove `AudioEnginePronunciationPort` |
| `test/features/reader/runtime/reader_session_analytics_test.dart` | Update `_FakeAudioPort` → `_FakePageAudio` |
| `test/features/reader/runtime/reader_session_narration_pause_test.dart` | Update `_CountingAudioPort` → `_CountingPageAudio` |
| `test/features/reader/runtime/reader_session_page_reset_test.dart` | Update `_FakeAudioPort` → `_FakePageAudio` |
| `test/features/reader/runtime/reader_word_help_engine_test.dart` | Update `_FakePronunciationAudioPort` → `_FakePronunciationPlayer` |

### Deleted files

| File | Reason |
|------|--------|
| `lib/src/features/reader/runtime/ports/audio_port.dart` | Replaced by `PageAudio` in `lib/src/audio/page_audio.dart` |
| `lib/src/features/reader/runtime/adapters/audio_engine_audio_port.dart` | No longer needed — `AudioEngine` implements `PageAudio` directly |

### New test files

| File | Tests |
|------|-------|
| `test/audio/audio_engine_test.dart` | Orchestration logic: page load, race conditions, toggle state, practice ducking, pronunciation sequencing |

---

## Task 1: Define `RawPlayer` interface + `JustAudioPlayer` implementation

**Files:**
- Create: `lib/src/audio/raw_player.dart`
- Create: `lib/src/audio/just_audio_player.dart`

- [ ] **Step 1: Create `RawPlayer` abstract class**

Create `lib/src/audio/raw_player.dart`:

```dart
import 'dart:async';

enum RawPlayerState { idle, loading, ready, completed }

enum RawLoopMode { off, one }

abstract class RawPlayer {
  Future<void> setSource(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setLoopMode(RawLoopMode mode);

  bool get isPlaying;
  Duration get position;
  Duration? get duration;
  RawPlayerState get state;

  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Stream<RawPlayerState> get stateStream;

  Future<void> dispose();
}
```

- [ ] **Step 2: Create `JustAudioPlayer` implementation**

Create `lib/src/audio/just_audio_player.dart`:

```dart
import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'raw_player.dart';

class JustAudioPlayer implements RawPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> setSource(String url) => _player.setUrl(url);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setLoopMode(RawLoopMode mode) => _player.setLoopMode(
        mode == RawLoopMode.one ? LoopMode.one : LoopMode.off,
      );

  @override
  bool get isPlaying => _player.playing;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  RawPlayerState get state {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return RawPlayerState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return RawPlayerState.loading;
      case ProcessingState.ready:
        return RawPlayerState.ready;
      case ProcessingState.completed:
        return RawPlayerState.completed;
    }
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<RawPlayerState> get stateStream => _player.processingStateStream.map(
        (ps) {
          switch (ps) {
            case ProcessingState.idle:
              return RawPlayerState.idle;
            case ProcessingState.loading:
            case ProcessingState.buffering:
              return RawPlayerState.loading;
            case ProcessingState.ready:
              return RawPlayerState.ready;
            case ProcessingState.completed:
              return RawPlayerState.completed;
          }
        },
      );

  @override
  Future<void> dispose() => _player.dispose();
}
```

- [ ] **Step 3: Run `flutter analyze`**

Run: `flutter analyze lib/src/audio/raw_player.dart lib/src/audio/just_audio_player.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/src/audio/raw_player.dart lib/src/audio/just_audio_player.dart
git commit -m "feat(audio): add RawPlayer interface + JustAudioPlayer implementation"
```

---

## Task 2: Define `AudioSnapshot` + `PageAudio` interface

**Files:**
- Create: `lib/src/audio/page_audio.dart`

- [ ] **Step 1: Create `AudioSnapshot` + `PageAudio`**

Create `lib/src/audio/page_audio.dart`:

```dart
import 'dart:async';

import '../data/models.dart';

class AudioSnapshot {
  const AudioSnapshot({
    this.isNarrationPlaying = false,
    this.isSoundscapePlaying = false,
    this.narrationPosition = Duration.zero,
  });

  final bool isNarrationPlaying;
  final bool isSoundscapePlaying;
  final Duration narrationPosition;

  AudioSnapshot copyWith({
    bool? isNarrationPlaying,
    bool? isSoundscapePlaying,
    Duration? narrationPosition,
  }) {
    return AudioSnapshot(
      isNarrationPlaying: isNarrationPlaying ?? this.isNarrationPlaying,
      isSoundscapePlaying: isSoundscapePlaying ?? this.isSoundscapePlaying,
      narrationPosition: narrationPosition ?? this.narrationPosition,
    );
  }
}

abstract interface class PageAudio {
  Future<void> loadPage(PageData page);
  Future<void> toggleNarration();
  Future<void> toggleSoundscape();
  Future<void> setNarrationVolume(double volume);
  Future<void> setSoundscapeVolume(double volume);
  Future<void> duckForPractice();
  Future<void> restoreFromPractice();
  Stream<AudioSnapshot> get states;
}
```

Note: `dispose()` is intentionally NOT on `PageAudio`. The provider owns the engine lifecycle. Callers must not dispose shared infrastructure.

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze lib/src/audio/page_audio.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/src/audio/page_audio.dart
git commit -m "feat(audio): add PageAudio interface + AudioSnapshot value type"
```

---

## Task 3: Define `PronunciationPlayer` interface

**Files:**
- Create: `lib/src/audio/pronunciation_player.dart`

- [ ] **Step 1: Create `PronunciationPlayer` interface**

Create `lib/src/audio/pronunciation_player.dart`:

```dart
abstract interface class PronunciationPlayer {
  Future<void> play(List<String> urls);
  Future<void> stop();
  Stream<Duration> get position;
  Stream<bool> get playing;
}
```

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze lib/src/audio/pronunciation_player.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/src/audio/pronunciation_player.dart
git commit -m "feat(audio): add PronunciationPlayer interface"
```

---

## Task 4: Atomic migration — AudioEngine + providers + session + word help + tests

**Files:**
- Modify: `lib/src/audio/audio_engine.dart`
- Modify: `lib/src/audio/audio_providers.dart`
- Modify: `lib/src/features/reader/runtime/reader_session_impl.dart`
- Modify: `lib/src/features/reader/runtime/providers/reader_session_provider.dart`
- Modify: `lib/src/features/reader/runtime/providers/reader_word_help_provider.dart`
- Modify: `lib/src/features/reader/runtime/word_help/reader_word_help.dart`
- Modify: `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart`
- Modify: `lib/src/features/reader/runtime/word_help/reader_word_help_adapters.dart`
- Delete: `lib/src/features/reader/runtime/ports/audio_port.dart`
- Delete: `lib/src/features/reader/runtime/adapters/audio_engine_audio_port.dart`
- Modify: `test/features/reader/runtime/reader_session_analytics_test.dart`
- Modify: `test/features/reader/runtime/reader_session_narration_pause_test.dart`
- Modify: `test/features/reader/runtime/reader_session_page_reset_test.dart`
- Modify: `test/features/reader/runtime/reader_word_help_engine_test.dart`
- Create: `test/audio/audio_engine_test.dart`

> **Why atomic:** The new `AudioEngine` constructor requires `playerFactory`, which breaks `audio_providers.dart`. The old `AudioEngineAudioPort` adapter references removed methods (`ensureInitialized`, `transitionToPage`, `narrationPosition`). These must all change together or the repo won't compile.

### 4A: Rewrite `AudioEngine`

- [ ] **Step 1: Replace `lib/src/audio/audio_engine.dart`**

```dart
import 'dart:async';

import 'package:audio_session/audio_session.dart';

import '../data/models.dart';
import 'page_audio.dart';
import 'pronunciation_player.dart';
import 'raw_player.dart';

typedef RawPlayerFactory = RawPlayer Function();

class AudioEngine implements PageAudio, PronunciationPlayer {
  AudioEngine({
    required RawPlayerFactory playerFactory,
    RawPlayer? narrationPlayer,
    RawPlayer? soundscapePlayer,
    RawPlayer? pronunciationPlayer,
  })  : _narration = narrationPlayer ?? playerFactory(),
        _soundscape = soundscapePlayer ?? playerFactory(),
        _pronunciation = pronunciationPlayer ?? playerFactory();

  final RawPlayer _narration;
  final RawPlayer _soundscape;
  final RawPlayer _pronunciation;

  static const Duration _restartThreshold = Duration(milliseconds: 250);

  final StreamController<bool> _pronunciationPlayingController =
      StreamController<bool>.broadcast();
  final StreamController<AudioSnapshot> _snapshotController =
      StreamController<AudioSnapshot>.broadcast();

  bool _initialized = false;
  int _pageAudioRequestId = 0;
  int _pronunciationRequestId = 0;
  String? _currentSoundscapeUrl;

  bool _narrationActive = false;
  bool _soundscapeActive = false;
  double _soundscapeTargetVolume = 0.6;

  bool _wasNarrationPlayingBeforePractice = false;
  double _soundscapeVolumeBeforePractice = 0.6;

  StreamSubscription<Duration>? _narrationPositionSub;
  StreamSubscription<bool>? _narrationPlayingSub;
  StreamSubscription<bool>? _soundscapePlayingSub;

  AudioSnapshot _currentSnapshot = const AudioSnapshot();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await _soundscape.setLoopMode(RawLoopMode.off);
    await _soundscape.setVolume(_soundscapeTargetVolume);

    _narrationPositionSub = _narration.positionStream.listen((pos) {
      _currentSnapshot = _currentSnapshot.copyWith(narrationPosition: pos);
      _emitSnapshot();
    });
    _narrationPlayingSub = _narration.playingStream.listen((playing) {
      _currentSnapshot = _currentSnapshot.copyWith(isNarrationPlaying: playing);
      _emitSnapshot();
    });
    _soundscapePlayingSub = _soundscape.playingStream.listen((playing) {
      _currentSnapshot =
          _currentSnapshot.copyWith(isSoundscapePlaying: playing);
      _emitSnapshot();
    });

    _initialized = true;
  }

  void _emitSnapshot() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_currentSnapshot);
    }
  }

  // ---------------------------------------------------------------------------
  // PageAudio
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadPage(PageData page) async {
    await _ensureInitialized();
    final requestId = ++_pageAudioRequestId;

    // Always stop narration — it's page-specific.
    await _narration.stop();
    if (requestId != _pageAudioRequestId) return;

    final narrationUrl = page.narrationUrl;
    if (narrationUrl != null && narrationUrl.isNotEmpty) {
      await _narration.setSource(narrationUrl);
      if (requestId != _pageAudioRequestId) return;
      if (_narrationActive) {
        await _narration.play();
      }
    }

    // Soundscape: only stop/reload if URL changed (preserves continuity).
    final soundscapeUrl = page.soundscapeUrl;
    final hasSoundscape = soundscapeUrl != null && soundscapeUrl.isNotEmpty;
    final isSameSoundscape =
        hasSoundscape && soundscapeUrl == _currentSoundscapeUrl;

    if (isSameSoundscape) return;

    await _soundscape.stop();
    if (requestId != _pageAudioRequestId) return;

    if (hasSoundscape) {
      await _soundscape.setVolume(_soundscapeTargetVolume);
      await _soundscape.setSource(soundscapeUrl!);
      _currentSoundscapeUrl = soundscapeUrl;
      if (requestId != _pageAudioRequestId) return;
      if (_soundscapeActive) {
        await _soundscape.play();
      }
    } else {
      _currentSoundscapeUrl = null;
    }
  }

  @override
  Future<void> toggleNarration() async {
    await _ensureInitialized();
    if (_narrationActive && _narration.isPlaying) {
      _narrationActive = false;
      await _narration.pause();
    } else {
      await _restartIfCompleted(_narration);
      _narrationActive = true;
      await _narration.play();
    }
  }

  @override
  Future<void> toggleSoundscape() async {
    await _ensureInitialized();
    if (_soundscapeActive && _soundscape.isPlaying) {
      _soundscapeActive = false;
      await _soundscape.pause();
    } else {
      await _restartIfCompleted(_soundscape);
      _soundscapeActive = true;
      await _soundscape.play();
    }
  }

  @override
  Future<void> setNarrationVolume(double volume) =>
      _narration.setVolume(volume);

  @override
  Future<void> setSoundscapeVolume(double volume) {
    _soundscapeTargetVolume = volume;
    return _soundscape.setVolume(volume);
  }

  @override
  Future<void> duckForPractice() async {
    _wasNarrationPlayingBeforePractice =
        _narrationActive && _narration.isPlaying;
    _soundscapeVolumeBeforePractice = _soundscapeTargetVolume;

    if (_wasNarrationPlayingBeforePractice) {
      _narrationActive = false;
      await _narration.pause();
    }
    await setSoundscapeVolume(0.3);
  }

  @override
  Future<void> restoreFromPractice() async {
    await setSoundscapeVolume(_soundscapeVolumeBeforePractice);

    if (_wasNarrationPlayingBeforePractice && !_narration.isPlaying) {
      _narrationActive = true;
      await _narration.play();
    }
  }

  @override
  Stream<AudioSnapshot> get states => _snapshotController.stream;

  bool get isNarrationActive => _narrationActive;
  bool get isSoundscapeActive => _soundscapeActive;

  // ---------------------------------------------------------------------------
  // PronunciationPlayer
  // ---------------------------------------------------------------------------

  @override
  Future<void> play(List<String> urls) async {
    final filtered = urls.where((u) => u.isNotEmpty).toList(growable: false);
    if (filtered.isEmpty) return;

    await _ensureInitialized();
    final requestId = ++_pronunciationRequestId;
    await _pronunciation.stop();
    if (requestId != _pronunciationRequestId) return;

    _emitPronunciationPlaying(true);
    try {
      for (final url in filtered) {
        if (requestId != _pronunciationRequestId) return;
        await _pronunciation.setSource(url);
        if (requestId != _pronunciationRequestId) return;
        await _pronunciation.seek(Duration.zero);
        // Subscribe BEFORE play() to avoid missing the completed event.
        final done = _waitForPronunciationSegmentToEnd(requestId);
        await _pronunciation.play();
        await done;
        if (requestId != _pronunciationRequestId) return;
      }
    } finally {
      if (requestId == _pronunciationRequestId) {
        _emitPronunciationPlaying(false);
      }
    }
  }

  @override
  Future<void> stop() async {
    _pronunciationRequestId++;
    await _pronunciation.stop();
    _emitPronunciationPlaying(false);
  }

  @override
  Stream<Duration> get position => _pronunciation.positionStream;

  @override
  Stream<bool> get playing => _pronunciationPlayingController.stream;

  bool get isPronunciationPlaying => _pronunciation.isPlaying;

  Future<void> _waitForPronunciationSegmentToEnd(int requestId) async {
    await _pronunciation.stateStream.firstWhere((state) {
      if (requestId != _pronunciationRequestId) return true;
      return state == RawPlayerState.completed ||
          state == RawPlayerState.idle;
    });
  }

  void _emitPronunciationPlaying(bool value) {
    if (_pronunciationPlayingController.isClosed) return;
    _pronunciationPlayingController.add(value);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await _narrationPositionSub?.cancel();
    await _narrationPlayingSub?.cancel();
    await _soundscapePlayingSub?.cancel();
    await _pronunciationPlayingController.close();
    await _snapshotController.close();
    await _narration.dispose();
    await _soundscape.dispose();
    await _pronunciation.dispose();
  }

  Future<void> _restartIfCompleted(RawPlayer player) async {
    final dur = player.duration;
    if (dur == null || dur <= Duration.zero) return;

    final restartCutoff =
        dur > _restartThreshold ? dur - _restartThreshold : Duration.zero;
    final isNearEnd = player.position >= restartCutoff;
    final isCompleted = player.state == RawPlayerState.completed;

    if (isNearEnd || isCompleted) {
      await player.seek(Duration.zero);
    }
  }
}
```

Key design decisions:
- **No `_playerFactory` field** — factory is only used in the initializer list, avoiding `unused_field` lint.
- **`loadPage` stops narration first, then checks soundscape URL** — only stops soundscape if URL changed, preserving the old `transitionToPage` dedup optimization.
- **`play()` subscribes to `stateStream` BEFORE calling `play()`** — `final done = _waitForPronunciationSegmentToEnd(requestId)` captures the future before `play()` fires, preventing missed completed events.
- **`dispose()` is NOT on `PageAudio`** — the provider owns the engine lifecycle. Callers must not dispose shared infrastructure.

### 4B: Update `audio_providers.dart`

- [ ] **Step 2: Replace `lib/src/audio/audio_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_engine.dart';
import 'just_audio_player.dart';
import 'page_audio.dart';
import 'pronunciation_player.dart';

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine(playerFactory: JustAudioPlayer.new);
  ref.onDispose(engine.dispose);
  return engine;
});

final pageAudioProvider = Provider<PageAudio>((ref) {
  return ref.watch(audioEngineProvider);
});

final pronunciationPlayerProvider = Provider<PronunciationPlayer>((ref) {
  return ref.watch(audioEngineProvider);
});
```

### 4C: Migrate `ReaderSessionImpl`

- [ ] **Step 3: Update `lib/src/features/reader/runtime/reader_session_impl.dart`**

Apply these changes:

1. Replace the import:
```dart
// Remove:
import 'ports/audio_port.dart';
// Add:
import '../../../audio/page_audio.dart';
```

2. Update constructor — `AudioPort audioPort` → `PageAudio pageAudio`:
```dart
class ReaderSessionImpl implements ReaderSession {
  ReaderSessionImpl({
    required PageAudio pageAudio,
    required SpeechPracticePort speechPort,
    required SchedulerPort scheduler,
    ReaderAnalyticsTracker? analyticsTracker,
  }) : _pageAudio = pageAudio,
       _speechPort = speechPort,
       _scheduler = scheduler,
       _analyticsTracker = analyticsTracker {
    _audioSnapshotSub = _pageAudio.states.listen((snapshot) {
      _emit(_state.copyWith(
        narrationPosition: snapshot.narrationPosition,
        isNarrationPlaying: snapshot.isNarrationPlaying,
        isSoundscapePlaying: snapshot.isSoundscapePlaying,
      ));
    });
  }

  final PageAudio _pageAudio;
```

3. Replace three stream subscriptions with one:
```dart
  StreamSubscription<AudioSnapshot>? _audioSnapshotSub;
```
Remove `_narrationPositionSub`, `_narrationPlayingSub`, `_soundscapePlayingSub`.

4. Replace all `_audioPort.` calls with `_pageAudio.`:
- `_audioPort.toggleNarration()` → `_pageAudio.toggleNarration()`
- `_audioPort.toggleSoundscape()` → `_pageAudio.toggleSoundscape()`
- `_audioPort.setNarrationVolume(...)` → `_pageAudio.setNarrationVolume(...)`
- `_audioPort.setSoundscapeVolume(...)` → `_pageAudio.setSoundscapeVolume(...)`
- Remove `_audioPort.ensureInitialized()` (now internal to engine)
- `_audioPort.loadPage(...)` → `_pageAudio.loadPage(...)`
- `_audioPort.transitionToPage(...)` → `_pageAudio.loadPage(...)`

5. Replace practice ducking in `_handlePracticePrimaryAction` (lines 237-266):
```dart
  Future<void> _handlePracticePrimaryAction() async {
    if (!_state.isListening) {
      await _ensureSpeechInitialized();
      if (!_speechAvailable) return;

      _soundscapeVolumeBeforePractice = _state.soundscapeVolume;
      await _pageAudio.duckForPractice();

      _emit(
        _state.copyWith(
          isPracticeMode: true,
          isListening: false,
          showCelebration: false,
          spokenWordIndices: const {},
          soundscapeVolume: 0.3,
        ),
      );
      await _startListening();
      return;
    }

    await _speechPort.stopListening();
    await _restorePracticeAudioState();
    _onListeningDone();
  }
```

6. Replace `_restorePracticeAudioState` (lines 275-289):
```dart
  Future<void> _restorePracticeAudioState() async {
    await _pageAudio.restoreFromPractice();
    _emit(
      _state.copyWith(
        soundscapeVolume: _soundscapeVolumeBeforePractice,
        isPracticeMode: false,
      ),
    );
  }
```

7. Remove the `_wasNarrationPlayingBeforePractice` field (line 54) — the engine tracks this internally now.

8. Update `dispose()` — do NOT call `_pageAudio.dispose()` (provider owns lifecycle):
```dart
  @override
  Future<void> dispose() async {
    _completeSpeechAttempt(reason: 'dispose');
    _analyticsTracker?.endSession(reason: 'provider_dispose');
    _celebrationTask?.cancel();
    await _audioSnapshotSub?.cancel();
    await _speechPort.dispose();
    await _controller.close();
    await _pageChangeController.close();
  }
```

### 4D: Update `reader_session_provider.dart`

- [ ] **Step 4: Replace `lib/src/features/reader/runtime/providers/reader_session_provider.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_providers.dart';
import '../../../../data/providers.dart';
import '../adapters/flutter_scheduler_port.dart';
import '../adapters/speech_to_text_practice_port.dart';
import '../reader_analytics_tracker.dart';
import '../reader_session.dart';
import '../reader_session_impl.dart';

final readerAnalyticsTrackerProvider = Provider<ReaderAnalyticsTracker>((ref) {
  return ReaderAnalyticsTracker(
    analyticsRepository: ref.watch(analyticsRepositoryProvider),
  );
});

final readerSessionProvider = Provider<ReaderSession>((ref) {
  final pageAudio = ref.watch(pageAudioProvider);
  final session = ReaderSessionImpl(
    pageAudio: pageAudio,
    speechPort: SpeechToTextPracticePort(),
    scheduler: FlutterSchedulerPort(),
    analyticsTracker: ref.watch(readerAnalyticsTrackerProvider),
  );

  ref.onDispose(() {
    session.dispose();
  });

  return session;
});
```

### 4E: Migrate word help

- [ ] **Step 5: Update `lib/src/features/reader/runtime/word_help/reader_word_help.dart`**

Replace `PronunciationAudioPort` (lines 109-113) with a typedef:

```dart
// Remove the old PronunciationAudioPort definition (lines 109-113).
// Add import at top of file:
import '../../../../audio/pronunciation_player.dart';

// Replace the interface with a typedef:
typedef PronunciationAudioPort = PronunciationPlayer;
```

- [ ] **Step 6: Update `lib/src/features/reader/runtime/word_help/reader_word_help_engine.dart`**

Find all calls to `_pronunciationAudio.playSequence(...)` and replace with `_pronunciationAudio.play(...)`.

- [ ] **Step 7: Remove `AudioEnginePronunciationPort` from `reader_word_help_adapters.dart`**

In `lib/src/features/reader/runtime/word_help/reader_word_help_adapters.dart`, remove the `AudioEnginePronunciationPort` class (lines 21-35) and its import of `audio_engine.dart`.

- [ ] **Step 8: Update `lib/src/features/reader/runtime/providers/reader_word_help_provider.dart`**

Replace `ref.watch(audioEngineProvider)` + `AudioEnginePronunciationPort(audioEngine)` with:
```dart
final pronunciationPlayer = ref.watch(pronunciationPlayerProvider);
```

Pass `pronunciationPlayer` directly as the `pronunciationAudio:` argument. Remove the import of `audio_engine.dart` if no longer needed. The import of `audio_providers.dart` stays (for `pronunciationPlayerProvider`).

### 4F: Delete old files

- [ ] **Step 9: Delete old `AudioPort` interface + adapter**

```bash
rm lib/src/features/reader/runtime/ports/audio_port.dart
rm lib/src/features/reader/runtime/adapters/audio_engine_audio_port.dart
```

### 4G: Update test fakes

- [ ] **Step 10: Update `_FakeAudioPort` in `reader_session_analytics_test.dart`**

Replace `_FakeAudioPort` (lines 249-298) with:

```dart
class _FakePageAudio implements PageAudio {
  final _snapshotController = StreamController<AudioSnapshot>.broadcast();
  bool isNarrationPlaying = false;
  bool isSoundscapePlaying = false;

  @override
  Stream<AudioSnapshot> get states => _snapshotController.stream;

  @override
  Future<void> loadPage(PageData page) async {}

  @override
  Future<void> toggleNarration() async {
    isNarrationPlaying = !isNarrationPlaying;
    _snapshotController.add(AudioSnapshot(
      isNarrationPlaying: isNarrationPlaying,
      isSoundscapePlaying: isSoundscapePlaying,
    ));
  }

  @override
  Future<void> toggleSoundscape() async {
    isSoundscapePlaying = !isSoundscapePlaying;
    _snapshotController.add(AudioSnapshot(
      isNarrationPlaying: isNarrationPlaying,
      isSoundscapePlaying: isSoundscapePlaying,
    ));
  }

  @override
  Future<void> setNarrationVolume(double volume) async {}

  @override
  Future<void> setSoundscapeVolume(double volume) async {}

  @override
  Future<void> duckForPractice() async {
    if (isNarrationPlaying) {
      isNarrationPlaying = false;
      _snapshotController.add(AudioSnapshot(
        isNarrationPlaying: false,
        isSoundscapePlaying: isSoundscapePlaying,
      ));
    }
  }

  @override
  Future<void> restoreFromPractice() async {}
}
```

Update the test setup to use `_FakePageAudio` and pass `pageAudio:` to `ReaderSessionImpl`. Update imports: add `import 'package:storia_mobile/src/audio/page_audio.dart';`, remove the old `audio_port.dart` import.

- [ ] **Step 11: Update `_CountingAudioPort` in `reader_session_narration_pause_test.dart`**

Replace with:

```dart
class _CountingPageAudio implements PageAudio {
  final _snapshotController = StreamController<AudioSnapshot>.broadcast();
  int toggleNarrationCalls = 0;

  @override
  Stream<AudioSnapshot> get states => _snapshotController.stream;
  @override
  Future<void> loadPage(PageData page) async {}
  @override
  Future<void> toggleNarration() async {
    toggleNarrationCalls++;
  }
  @override
  Future<void> toggleSoundscape() async {}
  @override
  Future<void> setNarrationVolume(double volume) async {}
  @override
  Future<void> setSoundscapeVolume(double volume) async {}
  @override
  Future<void> duckForPractice() async {}
  @override
  Future<void> restoreFromPractice() async {}
}
```

Update test setup, constructor call, and imports.

- [ ] **Step 12: Update `_FakeAudioPort` in `reader_session_page_reset_test.dart`**

Replace with:

```dart
class _FakePageAudio implements PageAudio {
  final _snapshotController = StreamController<AudioSnapshot>.broadcast();

  @override
  Stream<AudioSnapshot> get states => _snapshotController.stream;
  @override
  Future<void> loadPage(PageData page) async {}
  @override
  Future<void> toggleNarration() async {}
  @override
  Future<void> toggleSoundscape() async {}
  @override
  Future<void> setNarrationVolume(double volume) async {}
  @override
  Future<void> setSoundscapeVolume(double volume) async {}
  @override
  Future<void> duckForPractice() async {}
  @override
  Future<void> restoreFromPractice() async {}
}
```

Update test setup, constructor call, and imports.

- [ ] **Step 13: Update `_FakePronunciationAudioPort` in `reader_word_help_engine_test.dart`**

Replace with:

```dart
class _FakePronunciationPlayer implements PronunciationPlayer {
  final _positionController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final playedSequences = <List<String>>[];
  var stopCount = 0;
  Object? playError;
  Completer<void>? playCompleter;

  @override
  Stream<Duration> get position => _positionController.stream;

  @override
  Stream<bool> get playing => _playingController.stream;

  void emitPosition(Duration position) => _positionController.add(position);

  @override
  Future<void> play(List<String> urls) async {
    final error = playError;
    if (error != null) {
      throw error;
    }
    playedSequences.add(List<String>.of(urls));
    final completer = playCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
    final completer = playCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> dispose() async {
    await _positionController.close();
    await _playingController.close();
  }
}
```

Note: `stop()` completes the pending `playCompleter` to unblock any in-flight `play()` call. This prevents test hangs in cancel-and-replace scenarios.

Update import: `import 'package:storia_mobile/src/audio/pronunciation_player.dart';`
Update all references from `_FakePronunciationAudioPort` to `_FakePronunciationPlayer`.

### 4H: Create AudioEngine tests

- [ ] **Step 14: Create `test/audio/audio_engine_test.dart`**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:storia_mobile/src/audio/audio_engine.dart';
import 'package:storia_mobile/src/audio/page_audio.dart';
import 'package:storia_mobile/src/audio/pronunciation_player.dart';
import 'package:storia_mobile/src/audio/raw_player.dart';
import 'package:storia_mobile/src/data/models.dart';

class FakeRawPlayer implements RawPlayer {
  String? currentUrl;
  bool playing = false;
  double volume = 1.0;
  Duration position = Duration.zero;
  Duration? duration;
  RawPlayerState _state = RawPlayerState.idle;
  RawLoopMode loopMode = RawLoopMode.off;

  final _positionController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _stateController = StreamController<RawPlayerState>.broadcast();

  int setSourceCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int seekCalls = 0;
  int disposeCalls = 0;
  bool autoComplete = true;
  Completer<void>? playCompleter;

  @override
  Future<void> setSource(String url) async {
    setSourceCalls++;
    currentUrl = url;
    _state = RawPlayerState.ready;
    _stateController.add(_state);
  }

  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
    _playingController.add(true);
    _state = RawPlayerState.ready;
    _stateController.add(_state);
    final completer = playCompleter;
    if (completer != null) {
      await completer.future;
      return;
    }
    if (autoComplete) {
      await Future<void>.delayed(Duration.zero);
      _state = RawPlayerState.completed;
      _stateController.add(_state);
      playing = false;
      _playingController.add(false);
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playing = false;
    _playingController.add(false);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playing = false;
    _playingController.add(false);
    position = Duration.zero;
    // Unblock any pending playCompleter to prevent test hangs.
    final completer = playCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> seek(Duration pos) async {
    seekCalls++;
    position = pos;
  }

  @override
  Future<void> setVolume(double v) async {
    volume = v;
  }

  @override
  Future<void> setLoopMode(RawLoopMode mode) async {
    loopMode = mode;
  }

  @override
  bool get isPlaying => playing;

  @override
  RawPlayerState get state => _state;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<RawPlayerState> get stateStream => _stateController.stream;

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _positionController.close();
    await _playingController.close();
    await _stateController.close();
  }

  void emitPosition(Duration d) {
    position = d;
    _positionController.add(d);
  }

  void emitCompleted() {
    _state = RawPlayerState.completed;
    _stateController.add(_state);
  }
}

PageData _page({String? narration, String? soundscape}) {
  return PageData(
    id: 'p1',
    pageNumber: 1,
    narrationUrl: narration,
    soundscapeUrl: soundscape,
  );
}

void main() {
  late FakeRawPlayer narration;
  late FakeRawPlayer soundscape;
  late FakeRawPlayer pronunciation;
  late AudioEngine engine;

  setUp(() {
    narration = FakeRawPlayer();
    soundscape = FakeRawPlayer();
    pronunciation = FakeRawPlayer();
    engine = AudioEngine(
      playerFactory: () => throw UnimplementedError(),
      narrationPlayer: narration,
      soundscapePlayer: soundscape,
      pronunciationPlayer: pronunciation,
    );
  });

  tearDown(() async {
    await engine.dispose();
  });

  group('PageAudio', () {
    test('loadPage sets narration URL and plays when active', () async {
      await engine.loadPage(_page(narration: 'narration.mp3'));

      expect(narration.setSourceCalls, 1);
      expect(narration.currentUrl, 'narration.mp3');
    });

    test('loadPage stops narration before loading', () async {
      await engine.loadPage(_page(narration: 'a.mp3'));

      expect(narration.stopCalls, greaterThanOrEqualTo(1));
    });

    test('loadPage skips soundscape restart when URL unchanged', () async {
      await engine.loadPage(_page(soundscape: 'same.mp3'));
      final soundscapeStopsAfterFirst = soundscape.stopCalls;

      await engine.loadPage(_page(soundscape: 'same.mp3'));

      expect(soundscape.stopCalls, soundscapeStopsAfterFirst);
    });

    test('loadPage stops soundscape when URL changes', () async {
      await engine.loadPage(_page(soundscape: 'a.mp3'));
      await engine.loadPage(_page(soundscape: 'b.mp3'));

      expect(soundscape.stopCalls, greaterThanOrEqualTo(2));
      expect(soundscape.currentUrl, 'b.mp3');
    });

    test('toggleNarration flips state', () async {
      expect(engine.isNarrationActive, false);
      await engine.toggleNarration();
      expect(engine.isNarrationActive, true);
      expect(narration.playCalls, greaterThanOrEqualTo(1));
    });

    test('toggleSoundscape flips state', () async {
      expect(engine.isSoundscapeActive, false);
      await engine.toggleSoundscape();
      expect(engine.isSoundscapeActive, true);
    });

    test('setNarrationVolume delegates to player', () async {
      await engine.setNarrationVolume(0.5);
      expect(narration.volume, 0.5);
    });

    test('setSoundscapeVolume updates target and player', () async {
      await engine.setSoundscapeVolume(0.8);
      expect(soundscape.volume, 0.8);
    });

    test('duckForPractice saves state, pauses narration, ducks soundscape',
        () async {
      await engine.toggleNarration();
      await engine.setSoundscapeVolume(0.6);

      await engine.duckForPractice();

      expect(soundscape.volume, 0.3);
      expect(narration.pauseCalls, greaterThanOrEqualTo(1));
    });

    test('restoreFromPractice restores volume and resumes narration',
        () async {
      await engine.toggleNarration();
      await engine.setSoundscapeVolume(0.6);
      await engine.duckForPractice();

      await engine.restoreFromPractice();

      expect(soundscape.volume, 0.6);
    });

    test('states stream emits AudioSnapshot on narration playing change',
        () async {
      final snapshots = <AudioSnapshot>[];
      final sub = engine.states.listen(snapshots.add);

      await engine.toggleNarration();
      await Future<void>.delayed(Duration.zero);

      expect(snapshots.any((s) => s.isNarrationPlaying), true);
      await sub.cancel();
    });
  });

  group('PronunciationPlayer', () {
    test('play plays URLs sequentially', () async {
      await engine.play(['a.mp3', 'b.mp3']);

      expect(pronunciation.setSourceCalls, 2);
    });

    test('play with empty list is a no-op', () async {
      await engine.play([]);

      expect(pronunciation.setSourceCalls, 0);
    });

    test('play filters empty URLs', () async {
      await engine.play(['a.mp3', '', 'b.mp3']);

      expect(pronunciation.setSourceCalls, 2);
    });

    test('stop cancels pronunciation', () async {
      await engine.stop();

      expect(pronunciation.stopCalls, greaterThanOrEqualTo(1));
    });

    test('second play call cancels first (cancel-and-replace)', () async {
      pronunciation.autoComplete = false;
      pronunciation.playCompleter = Completer<void>();
      final first = engine.play(['a.mp3']);

      // stop() on FakeRawPlayer completes the pending playCompleter,
      // unblocking the first play call.
      pronunciation.playCompleter = null;
      pronunciation.autoComplete = true;
      await engine.play(['b.mp3']);
      await first;

      expect(pronunciation.stopCalls, greaterThanOrEqualTo(1));
    });
  });

  group('race conditions', () {
    test('rapid loadPage calls — second call wins', () async {
      await engine.loadPage(_page(narration: 'a.mp3'));
      await engine.loadPage(_page(narration: 'b.mp3'));

      expect(narration.currentUrl, 'b.mp3');
    });

    test('second pronunciation play cancels first', () async {
      await engine.play(['a.mp3']);
      await engine.play(['b.mp3']);

      expect(pronunciation.currentUrl, 'b.mp3');
    });
  });

  group('restart if completed', () {
    test('toggleNarration seeks to zero when player is completed', () async {
      narration.duration = const Duration(seconds: 10);
      narration.position = const Duration(seconds: 10);
      narration.emitCompleted();

      await engine.toggleNarration();

      expect(narration.seekCalls, greaterThanOrEqualTo(1));
      expect(narration.playCalls, greaterThanOrEqualTo(1));
    });
  });
}
```

### 4I: Verify

- [ ] **Step 15: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 16: Run all tests**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 17: Commit**

```bash
git add -A
git commit -m "refactor(audio): extract PageAudio + PronunciationPlayer interfaces, RawPlayer backend abstraction"
```

---

## Task 5: Expand `AudioEngine` test coverage

**Files:**
- Modify: `test/audio/audio_engine_test.dart`

- [ ] **Step 1: Add soundscape continuity test**

Append to the `PageAudio` group in `test/audio/audio_engine_test.dart`:

```dart
    test('loadPage does not stop soundscape when URL is the same', () async {
      await engine.loadPage(_page(soundscape: 'ambient.mp3'));
      final stopsAfterFirst = soundscape.stopCalls;

      await engine.loadPage(_page(narration: 'narr.mp3', soundscape: 'ambient.mp3'));

      // Soundscape should not have been stopped again.
      expect(soundscape.stopCalls, stopsAfterFirst);
    });

    test('duckForPractice does not pause narration when not playing', () async {
      await engine.duckForPractice();

      expect(narration.pauseCalls, 0);
      expect(soundscape.volume, 0.3);
    });

    test('restoreFromPractice does not resume narration if it was not playing',
        () async {
      await engine.duckForPractice();
      await engine.restoreFromPractice();

      expect(narration.playCalls, 0);
    });
```

- [ ] **Step 2: Run all audio tests**

Run: `flutter test test/audio/audio_engine_test.dart`
Expected: All PASS.

- [ ] **Step 3: Commit**

```bash
git add test/audio/audio_engine_test.dart
git commit -m "test(audio): add soundscape continuity + practice edge case tests"
```

---

## Task 6: Final verification + cleanup

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 2: Run `flutter analyze`**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Run `./bin/verify.sh`**

Run: `./bin/verify.sh`
Expected: PASS (analyze + test gate).

- [ ] **Step 4: Verify no stale imports**

Run: `grep -r "just_audio" lib/src/audio/audio_engine.dart`
Expected: No results (engine uses `RawPlayer`, not `just_audio` directly).

Run: `grep -rn "audio_port.dart" lib/ test/`
Expected: No results (replaced by `PageAudio`).

Run: `grep -rn "AudioEngineAudioPort\|AudioEnginePronunciationPort" lib/ test/`
Expected: No results (adapters deleted).

- [ ] **Step 5: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "chore: final cleanup after AudioEngine interface extraction"
```
