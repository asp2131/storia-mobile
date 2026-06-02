# AAC Musical Utterances — Design

> Status: Design (approved decisions captured; open questions flagged for SLP review)
> Date: 2026-06-02
> Scope: New AAC sentence-builder feature with a musical-feedback layer. This doc covers the MVP demo and the data/audio architecture behind it.

## 1. Concept

An AAC (Augmentative and Alternative Communication) sentence builder where each tagged word maps to a musical element drawn from a single shared key/scale. As a user builds an utterance, the selected words can sound as a short melody, and a completed utterance can resolve into a soft "bloom" chord.

The musical layer is a **reward / engagement layer** that encourages multi-word utterances (a real AAC therapeutic goal). It is never the communication itself — spoken words (TTS) are the function; music decorates.

### Core guarantee: consonance by construction

Every musical contribution is a **scale degree**, not an absolute pitch, resolved at play time against one active `HarmonicPalette` (key + scale). Because every sound is drawn from one scale, any combination of words is consonant by construction. MVP palette is **major pentatonic** (no semitone clashes — "can't sound bad").

## 2. Locked decisions

| # | Decision | Choice |
|---|----------|--------|
| Target | What this feature is | AAC board / sentence builder |
| Music timing | When music happens | Both, configurable (tap + phrase) |
| Sound backend | Audio engine for music | `flutter_midi_pro`, behind an `AudioBackend` abstraction |
| Word identity | How words get music | Hybrid: semantic-tag default + word-specific override |
| Note vs chord | Default feedback shape | Adaptive — note-first default; chords via mode + send-bloom |
| Palette | Default harmony | Major pentatonic for MVP; realm/theme palettes later |
| Send behavior | On "send" | Replay melody → bloom chord for 2+ word utterances |
| Mapping storage | Where vocab/music lives | Local JSON asset (Dart core parses it) |
| Prototype location | First build | Standalone demo screen at `/aac-music-demo` |

### Resolved "uneasy" decisions

1. **MIDI timbre + latency → A.** Curated soft soundfont (bell/mallet/pad), preloaded, with a silent/quiet warm-up note on screen mount so the first real note isn't janky. Keep the `AudioBackend` abstraction so a `SampleBackend` can replace MIDI if the soundfont disappoints (hybrid bloom-as-sample is the documented escape hatch).
2. **TTS ↔ MIDI timing → B.** Parallel + gain-ducked. On tap: the note fires immediately (clean cause/effect for learners) and TTS fires in parallel; music sits under speech by gain. Fully-ordered timing is used **only** for the `onSend` recap, where we own the timeline.
3. **Send semantics → C.** Configurable "speak full sentence on send" toggle, **default ON** (matches real AAC device behavior). Music recap/bloom plays under/after the spoken sentence.
4. **Resolver + adaptive trigger → A + B now; C deferred.**
   - Resolver precedence: `word override → tag default → no music`, with per-board palette/instrument config layered on top.
   - Bloom trigger: mode-driven (chords only appear in "expressive" mode) **plus** utterance-length (single words = notes; 2+ word send = bloom chord).
   - Per-user progression profiles (words richening as a user demonstrates multi-word use) are **explicitly deferred**.
5. **Demo scope → A (minimal).** One fixed board, one palette, one soundfont; modes `off / phraseOnly / tapAndPhrase` only. No motifs, auditory icons, realm switching, or expressive mode in the demo. The data model stays extensible for them.

### Speech engine decision

- **MVP demo uses `flutter_tts`** (already vendored in `third_party/`, iOS-ready, no new model assets), accessed through a `SpeechSynth` interface.
- **`piper_tts_plugin` is ruled out for now** — Android + Windows only; no iOS (a hard requirement for this app).
- **`sherpa_onnx` is a documented follow-up spike.** It supports the full platform matrix (incl. iOS arm64/macOS), is Apache-2.0, offline, and — critically — **returns raw audio samples (Float32 + sample rate)** instead of fire-and-forget. That makes speech timing and music gain-ducking *deterministic* (it removes the "`speak()` returns on dispatch, not completion" gap), and could eventually replace both `flutter_tts` and `speech_to_text`. Spike one voice on iOS + Android, measuring synth latency and app-size cost (native libs per arch + ~10–60MB per voice model; per-model licensing must be checked).

## 3. Architecture

### Layers

```
JSON asset (vocabulary + music mapping + palette/instrument config)
        │  parsed by
        ▼
Dart core (no Flutter deps, unit-testable)
  ├── music_theory      — PitchClass, Scale, Pitch, HarmonicPalette
  ├── word_model        — AacWord, MusicalRole, tags, regions
  ├── role_resolver     — word override → tag default → none
  ├── consonance_engine — degree→pitch, deClash, bloomChord
  └── sequencer         — utterance → timed events; enforces speech-first + gain headroom
        │  drives
        ▼
Adapters
  ├── SpeechSynth   (interface) → FlutterTtsSpeechSynth (MVP); SherpaOnnxSpeechSynth (spike)
  └── AudioBackend  (interface) → MidiAudioBackend (MVP, flutter_midi_pro);
                                  SampleAudioBackend (fallback / bloom-as-sample)
        │  presented by
        ▼
UI: AacMusicDemoScreen (standalone route /aac-music-demo)
```

### Key types (carried over / adjusted from the working sketch)

- `HarmonicPalette { root, scale, baseOctave }` → `pitchForDegree`, `chordForDegree` (pentatonic "stacked chord", not a classical triad — name it accordingly).
- `MusicalRole` stores a **scale degree**, kind (`note | chord | motif`), gain. Motif/expressive deferred from demo but kept in the model.
- `AacWord { id, label, row, col, region, tags, auditoryIconAsset?, musicalRole? }`. `id` and grid position are stable; speech is independent of any musical role.
- `RoleResolver` resolves a word's effective `MusicalRole` via `override → tag default → none` against board config.
- `ConsonanceEngine` resolves degrees to `Pitch`es; `deClash` only nudges octaves (can never introduce a wrong note); `bloomChord` collapses an utterance into one resolved chord.
- `UtteranceSequencer` with modes `off | phraseOnly | tapAndPhrase`. Enforces: speech dispatched first/parallel; every music gain passes a `musicHeadroom` multiplier so music can't reach speech level. `onSend` optionally speaks the full sentence (toggle, default ON) then plays the bloom.

## 4. MVP demo behavior

Board: small fixed grid including `I`, `want`, `more`, plus a few function words.

- **Tap a word:** TTS speaks the word (parallel) + an immediate quiet in-key note (`tapAndPhrase` mode). Note is gain-ducked under speech.
- **Send:** if "speak sentence on send" is ON (default), TTS speaks the full sentence; then the musical phrase replays in order and, for 2+ musical words, resolves on a soft bloom chord.
- **Modes:** `off` (no music), `phraseOnly` (silent build, music on send), `tapAndPhrase` (default).
- One palette (e.g. C or F major pentatonic), one soft soundfont, warm-up note on mount.

Currently shipped scaffolding: `/aac-music-demo` route + `AacMusicDemoScreen` placeholder + a Library top-bar music-note button (`Open AAC music demo`) with a passing navigation widget test.

## 5. Testing strategy

- **Pure-Dart unit tests** (no Flutter): palette degree resolution across keys; `deClash` never creates a sub-min-gap interval; `bloomChord` stays in-key for all-words-stacked stress; resolver precedence; sequencer ordering (speech-first, gain headroom clamp).
- **Widget tests:** demo screen renders board; tap triggers speech + (mocked) note; send triggers sentence speech + bloom; mode toggles change behavior. Use fake `SpeechSynth` / `AudioBackend` to assert call ordering and gains.
- **Navigation test:** Library → `/aac-music-demo` (already passing).
- TDD throughout (red → green → refactor).

## 6. Open questions (need SLP / Lori input)

1. **Send semantics in practice:** default ON for speak-on-send is our call — confirm it matches how target users expect a "send" to behave, and whether per-word TTS + sentence TTS feels redundant.
2. **Note-first vs occasional anchor chords:** is one-word-one-note legibility more valuable than richer anchor words for early learners?
3. **Multi-word reward framing:** validate the "longer utterance → richer resolution" mechanic reads as motivation, not noise. Avoid clinical claims until reviewed.
4. **Soundfont character:** which timbre is calmest / least likely to dysregulate.

## 7. Out of scope (deferred)

- Motifs, auditory icons (user's own dog bark on "dog"), realm/theme palette switching.
- Expressive mode and per-user musical progression profiles.
- sherpa_onnx adoption (spike first), ASR replacement of `speech_to_text`.
- Persistence/personalization of boards (Supabase-backed config).
