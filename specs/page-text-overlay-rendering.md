# Page Text Overlay on Illustration

This document explains how we render page text directly on top of the illustration in the reader.

## Overview

The reader supports three display modes in `components/PageRenderer.tsx`:

1. **Dynamic overlay mode** (preferred): render image plus positioned text elements from `page.overlay.elements`.
2. **Composited mode**: use a pre-composited image that already contains text.
3. **Fallback mode**: if no overlay exists, render `page.textContent` near the bottom over gradient scrims.

The overlaid text-on-illustration behavior is mode 1.

## Data contract

Overlay text is driven by `PageData.overlay` (`types/index.ts`):

- `overlay.version`
- `overlay.elements[]` where each `TextElement` includes:
  - `text`
  - position and size in percentages: `x`, `y`, `width`
  - typography: `fontFamily`, `fontSize`, `fontWeight`, `color`, `textAlign`
  - optional styling: `rotation`, `shadow`, `background`

Important: coordinates and sizing are percentages relative to the illustration bounds, not screen pixels.

## Rendering flow

### 1) Measure container and source image

In `PageRenderer`:

- `onLayout` captures the image container size (`imageDimensions`).
- `onLoad` captures original image size (`sourceImageDimensions`).

When overlay data exists, the image is rendered with `contentFit="contain"` so text and image share the same coordinate space.

### 2) Compute contained image rectangle

`computeContainedImageRect(...)` in `lib/textOverlay.ts` calculates where the contained image sits inside the full-screen view (x/y/width/height), accounting for letterboxing.

This gives the exact visual rectangle used by both the image and the overlay layer.

### 3) Mount overlay layer in the same rect

`PageRenderer` positions an absolutely positioned `overlayLayer` at the computed rectangle and renders:

- `OverlayTextLayer`

`OverlayTextLayer` then renders each `OverlayTextElement` inside that same width/height box.

### 4) Convert percentages to pixels per element

In `OverlayTextElement`:

- `left = (x / 100) * imageWidth`
- `top = (y / 100) * imageHeight`
- `width = (width / 100) * imageWidth`
- `fontSizePx = (fontSize / 100) * imageHeight`

This is why text stays anchored correctly as screen size changes.

## Typography, styling, and readability

- Font variants are resolved by `resolveFont(...)` in `lib/textOverlay.ts` using the configured family and numeric weight.
- Optional per-element styles are applied:
  - text shadow (`textShadowColor`, offset, radius)
  - background block (`backgroundColor`, padding, borderRadius)
  - rotation transform (`rotation` degrees)
- Line height is set to `fontSize * 1.3` for stable readability.

## Word highlighting and interaction

- Narration timing determines `activeWordIndex` in `PageRenderer`.
- `OverlayTextLayer` maps each element id to a global word-start index using `calculateWordStartsByElementId(...)`.
- `OverlayTextElement` tokenizes text (preserving spaces), computes each token's global index, and highlights active/pronounced words.
- If `onWordTap` is provided, each word becomes pressable and returns `(word, globalIndex)`.

## Motion behavior

Each overlay text element animates in when a page becomes active:

- staggered entrance delay: `180 + elementIndex * 40` ms
- fade + upward motion
- reset to hidden when page is inactive

This is implemented in `OverlayTextElement` with Reanimated.

## Fallback behavior (no structured overlay)

If `overlay.elements` is missing but `textContent + imageUrl` exist, `PageRenderer`:

- renders gradient scrims near the bottom
- renders `WordHighlighter` text block at the bottom of the image

This preserves legibility but does not support per-element positioning.

## Key files

- `components/PageRenderer.tsx`
- `components/reader/OverlayTextLayer.tsx`
- `components/reader/OverlayTextElement.tsx`
- `lib/textOverlay.ts`
- `types/index.ts`
