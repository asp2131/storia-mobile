# Audio Lifecycle Audit — Fix Plan

Generated: 2026-02-25

## Files to modify
- `lib/src/features/reader/reader_screen.dart`
- `lib/src/audio/audio_engine.dart`
- `lib/src/audio/audio_providers.dart`

---

## Fix 1 — C1: Wrong subscription cancel order in dispose() [CRITICAL]
**File:** `reader_screen.dart` lines 66–77

**Problem:** `unawaited(_stopAllAudio(audioEngine))` is called before subscriptions are cancelled. The pause calls emit on `playingStream`, triggering `setState` on a mid-dispose widget.

**Fix:** Cancel subscriptions FIRST, then fire the stop:
```dart
@override
void dispose() {
  _positionSubscription?.cancel();
  _narrationPlayingSubscription?.cancel();
  _soundscapePlayingSubscription?.cancel();

  final audioEngine = _audioEngine; // cached field, see Fix 6
  unawaited(_stopAllAudio(audioEngine));

  _narrationPositionNotifier.dispose();
  _pageController.dispose();
  super.dispose();
}
```

---

## Fix 2 — W8: LoopMode.off → LoopMode.all for soundscape [WARNING]
**File:** `audio_engine.dart` line 32

**Problem:** Soundscape silently stops after one play. No auto-restart logic exists.

**Fix:** Change to `LoopMode.all`:
```dart
await _soundscape.setLoopMode(LoopMode.all);  // also await it (was unawaited)
```

---

## Fix 3 — C3: ensureInitialized() concurrency guard [CRITICAL]
**File:** `audio_engine.dart` lines 24–36

**Problem:** Two concurrent callers both pass `_initialized == false` check.

**Fix:** Use a `Completer`-based guard:
```dart
Future<void>? _initFuture;

Future<void> ensureInitialized() => _initFuture ??= _doInit();

Future<void> _doInit() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  await _soundscape.setLoopMode(LoopMode.all);
  await _soundscape.setVolume(_soundscapeTargetVolume);
  _initialized = true;
}
```
Remove the `_initialized` bool check — the `??=` on `_initFuture` handles it.

---

## Fix 4 — C4: Missing requestId guard before setVolume/setUrl [CRITICAL]
**File:** `audio_engine.dart` lines 63–66 (loadPage) and 166–169 (transitionToPage)

**Problem:** No cancellation check between `setVolume` and `setUrl` — stale request can corrupt player state.

**Fix in loadPage (around line 63):**
```dart
if (soundscapeUrl != null && soundscapeUrl.isNotEmpty) {
  if (requestId != _pageAudioRequestId) return;  // ADD THIS
  await _soundscape.setVolume(_soundscapeTargetVolume);
  if (requestId != _pageAudioRequestId) return;  // ADD THIS
  await _soundscape.setUrl(soundscapeUrl);
  _currentSoundscapeUrl = soundscapeUrl;
  if (requestId != _pageAudioRequestId) return;
  if (_soundscapeActive) {
    await _soundscape.play();
  }
}
```

**Same pattern in transitionToPage (around line 166).**

---

## Fix 5 — C2: State mutation inside build() [CRITICAL]
**File:** `reader_screen.dart` lines 97, 104–109

**Problem:** `_loadedInitialAudio = true` and `_activePageIndex` clamping set in `build()`.

**Fix:** Move initial audio load to `initState` or a `didChangeDependencies`/`didUpdateWidget` override. For the `_loadedInitialAudio` pattern, trigger loadPage in initState via a post-frame callback:
```dart
@override
void initState() {
  super.initState();
  _audioEngine = ref.read(audioEngineProvider);
  _audioEngine.ensureInitialized();
  // ... subscription setup ...

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    final book = ref.read(currentBookProvider(widget.bookId)).valueOrNull;
    if (book != null && book.pages.isNotEmpty) {
      _audioEngine.loadPage(book.pages[_activePageIndex]);
    }
  });
}
```
Remove the `_loadedInitialAudio` flag and the block inside `build()`.

For the index clamping, move to a helper called before accessing `activePage`:
```dart
void _clampActivePageIndex(int pageCount) {
  if (_activePageIndex >= pageCount) {
    _activePageIndex = pageCount - 1;
  }
}
```
Call this from `didUpdateWidget` or at the top of a dedicated method, not inside `build()`.

---

## Fix 6 — W1 + W2: Cache engine ref + close guard [WARNING]
**File:** `reader_screen.dart`

**Problem:** `ref.read()` in dispose() is unsafe; `_handleClose` has no re-entrancy guard.

**Fix:** Add fields:
```dart
late final AudioEngine _audioEngine;
bool _isClosing = false;
```

In `initState`:
```dart
_audioEngine = ref.read(audioEngineProvider);
```

In `_handleClose`:
```dart
Future<void> _handleClose(AudioEngine audioEngine) async {
  if (_isClosing) return;
  _isClosing = true;
  await _stopAllAudio(audioEngine);
  if (!mounted) return;
  await Navigator.of(context).maybePop();
}
```

---

## Fix 7 — C5 + W7: Dispose ordering + disposed guard [CRITICAL]
**File:** `audio_engine.dart`, `audio_providers.dart`

**Problem:** Use-after-dispose possible if Riverpod container disposes engine while ReaderScreen is still calling methods.

**Fix:** Add `_disposed` flag to AudioEngine:
```dart
bool _disposed = false;

Future<void> pauseNarration() async {
  _narrationActive = false;
  if (_disposed) return;
  await _narration.pause();
}

Future<void> pauseSoundscape() async {
  _soundscapeActive = false;
  if (_disposed) return;
  await _soundscape.pause();
}

Future<void> dispose() async {
  _disposed = true;
  await _narration.dispose();
  await _soundscape.dispose();
}
```

---

## Fix 8 — W3: Volume state sync on re-open [WARNING]
**File:** `reader_screen.dart` lines 34–35

**Fix:** In initState, read from engine:
```dart
// After caching _audioEngine
_soundscapeVolume = _audioEngine._soundscapeTargetVolume;
```
This requires exposing a getter on AudioEngine:
```dart
double get soundscapeTargetVolume => _soundscapeTargetVolume;
```
For narration volume (W9), add matching persistent state:
```dart
double _narrationTargetVolume = 1.0;
double get narrationTargetVolume => _narrationTargetVolume;

Future<void> setNarrationVolume(double volume) {
  _narrationTargetVolume = volume;
  return _narration.setVolume(volume);
}
```

---

## Fix 9 — W4 + W5: mounted guards [WARNING]
**File:** `reader_screen.dart`

**addPostFrameCallback (line 106):**
```dart
WidgetsBinding.instance.addPostFrameCallback((_) async {
  if (!mounted) return;  // ADD THIS
  await audioEngine.loadPage(book.pages[_activePageIndex]);
});
```

**Modal slider callbacks (lines 244, 255):**
```dart
onChanged: (value) async {
  setModalState(() => _narrationVolume = value);
  if (mounted) setState(() => _narrationVolume = value);  // GUARD
  await audioEngine.setNarrationVolume(value);
},
```

---

## Fix 10 — W10: Toggle re-entrancy [WARNING]
**File:** `audio_engine.dart` lines 94–100, 118–124

**Fix:** Add in-flight guards:
```dart
bool _narrationToggling = false;

Future<void> toggleNarration() async {
  if (_narrationToggling) return;
  _narrationToggling = true;
  try {
    if (_narrationActive && _narration.playing) {
      await pauseNarration();
    } else {
      await playNarration();
    }
  } finally {
    _narrationToggling = false;
  }
}
```
Same pattern for `toggleSoundscape`.

---

## Notes (no code changes needed)
- N1: `setLoopMode` not awaited — fixed as part of Fix 3
- N2: unawaited `ensureInitialized()` in initState — fixed as part of Fix 5/6
- N3: async `onPageChanged` swallows errors — acceptable for now
- N4: `Future.wait` on two players — safe, no change needed
- N5: `maybePop()` — correct choice, no change needed
