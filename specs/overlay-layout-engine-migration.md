# Overlay Layout Engine Migration (Candidate #5)

## Goal
Deepen the overlay text rendering pipeline behind one boundary so `PageRenderer` and `OverlayTextLayer` do not coordinate layout/timing/highlighting details.

## New boundary

```dart
abstract interface class OverlayLayoutEngine {
  OverlayFrame build({
    required TextOverlayConfig overlay,
    required Size imageSize,
    required int activeWordIndex,
    required Set<int> spokenWordIndices,
    required bool isActive,
  });
}
```

## Migration steps

1. Introduce render-model types (`OverlayFrame`, `OverlayElementFrame`, `OverlayTokenFrame`).
2. Implement `OverlayLayoutEngineImpl` that handles:
   - word-start indexing across elements
   - tokenization (`\s+|\S+`)
   - highlight state (`spoken` and `narration active`)
   - element geometry/style resolution
3. Update `OverlayTextLayer` to consume `OverlayFrame`.
4. Update `OverlayTextElement` to render from `OverlayElementFrame` only.
5. Update `PageRenderer` to:
   - keep contained-image math and active-word computation
   - call engine and render `OverlayTextLayer(frame: frame)`.
6. Add unit tests at engine boundary and remove utility-coupled assumptions from UI.

## Expected outcomes

- Overlay behavior is centralized and boundary-testable.
- `PageRenderer` no longer depends on overlay micro-utilities.
- Adding future highlighting/layout behavior requires changing one deep module.
