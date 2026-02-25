# Storia RN to Flutter Migration Analysis

Generated from multi-agent review of `specs/storia_migration_plan (1).docx` and current RN codebase.

## Executive Read

- The migration plan is directionally strong and correctly identifies text overlay parity as the highest-risk subsystem.
- The current RN app can be migrated in phases, but a hard cut-over in 3 weeks is optimistic.
- A safer baseline is 4-6 weeks, with the biggest uncertainty in overlay + audio parity on real devices.

## What must stay 1:1

- Gesture/page physics thresholds and easing on the reader page transitions.
- Overlay math: contained image rect and percentage-to-pixel conversion.
- Font size scaling in overlay mode: `fontSize` is based on image height.
- Word highlighting semantics based on narration timing and global word indexing.
- Audio behavior: dual-player lifecycle, soundscape crossfade, intro-only fade logic, background playback.

## Highest Technical Risks

1. Overlay coordinate drift across aspect ratios and letterboxing states.
2. Word tokenization/index mismatches causing incorrect highlights.
3. Narration timestamp quality and sync drift.
4. Dual-audio race conditions during page changes.
5. iOS/Android background audio config differences.
6. Preload memory/network pressure on low-end devices.
7. Supabase JSON model mismatches and nullable-field edge cases.
8. Gesture conflicts (page swipe vs word tap).
9. Release signing/provisioning delays.
10. Behavior drift if unused/legacy RN paths are accidentally ported.

## Current RN Source of Truth

- Reader orchestration: `app/reader/[id].tsx`
- Overlay pipeline: `components/PageRenderer.tsx`, `components/reader/OverlayTextLayer.tsx`, `components/reader/OverlayTextElement.tsx`, `lib/textOverlay.ts`
- Audio hooks: `hooks/useAudioPlayer.ts`, `hooks/useReaderAudio.ts`
- Data access: `lib/api.ts`, `hooks/useBookData.ts`, `hooks/useReadingProgress.ts`

## Recommended Migration Strategy

- Keep RN app intact during buildout; run Flutter app side-by-side until parity is proven.
- Build Flutter in milestone order:
  1. Bootstrap + data layer
  2. Audio engine
  3. Library screen
  4. Overlay system parity
  5. Reader assembly
  6. Polish + store release
- Add quality gates early:
  - overlay math unit tests
  - golden tests for overlay placement on multiple screen sizes
  - integration checks for audio transitions/background behavior

## Realistic Timeline

- Best case: 2.5-3.5 weeks
- Likely: 4-6 weeks
- Worst case: 7-10+ weeks

## Repo Recommendation

- Use mono-repo with a new Flutter app directory while migrating.
- This keeps schema/docs/fixtures in one place and speeds parity checks.
- Re-evaluate repo split after GA if release cadence diverges.
