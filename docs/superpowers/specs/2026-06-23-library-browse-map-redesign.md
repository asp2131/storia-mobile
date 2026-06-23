# Library Redesign — "Storybook World" Browse Map

**Date:** 2026-06-23
**Status:** Design approved, pending spec review
**Feature area:** `lib/src/features/library/`

## Problem

Reviewer feedback on the current library:

> Do you want users to read books in order of the avatar's path, or can you move around? If the latter, lay out book options non-linearly. Is the path leading somewhere or just ending abruptly when you've read all the books for that age group? What's the point of the path? It may help to zoom out so the user can see more of the path and where the highlighted books for each tab are located, instead of clicking each book to continue along the path.

The current UI renders books on one centered vertical S-curve trail. The avatar walks node-to-node and the camera follows it, zoomed in. Reading-order gating was already removed, so movement is technically free — but the **path metaphor still implies linear order and a destination it doesn't have**. The path fights the product.

## Solution

Replace the linear path with a **flat, zoomed-out storybook world you browse freely.** No route line, no journey-with-an-end, no implied reading order. Books scatter organically across a 2D world; the camera is zoomed out so you see most of a tab's books at once.

This resolves all three feedback points:
- **Order?** Free — pick any book.
- **Path's point?** There is no path.
- **See highlighted books?** Yes — zoomed-out overview.

## Decisions (locked)

| Question | Decision |
|---|---|
| Direction | Zoomed-out browse map. Abandon the path. |
| Avatar | Keep. Tap book → avatar walks to it → arrival opens preview modal. |
| Layout | Organic 2D scatter (not grid, not themed regions). |
| Tabs (Quick/Longer) | Unchanged: hide non-matching books. Refit camera to the visible set after a filter change. |
| Camera | Zoomed out + gentle drag-to-pan. Books stay readable. |
| Avatar start | Center of the scatter. |
| Backdrop | Flat `StoriaColors.paper` + scattered decorative props (trees/bushes/clouds). **Drop** the TMX isometric tilemap and the parallax sync. |

## Architecture

### 1. Layout — `lib/src/features/library/core/library_map_layout.dart`

Rewrite from vertical S-curve to deterministic 2D organic scatter.

- Positions seeded by book index (stable across rebuilds — no reshuffle on every frame/filter).
- Balanced spread with a minimum spacing constraint so nodes don't overlap (node width is 80px).
- World bounds (`worldWidth` × `worldHeight`) computed from the actual scatter extent + breathing-room padding, instead of a fixed wide horizontal strip.
- Remove `trailXOffsets`, `trailTopFraction`, `trailStepFraction`, `trailBottomPaddingFraction`, `routeBaselineFraction` and the vertical-trail node math.
- Keep the pure/no-side-effect property and `==`/`hashCode`. Keep `computeVisibleIds` / `screenOffsetOfNode` semantics (updated for 2D).

**Scatter algorithm (deterministic):** seeded placement — e.g. a seeded jittered-grid or Poisson-ish sampling keyed on index — so it looks organic but is reproducible and collision-free. Single clear function: input `bookCount` + bounds → list of `Vector2`. Testable in isolation.

### 2. Game — `lib/src/features/library/game/library_game.dart`

- Use the 2D scatter positions for nodes (was `_nodePositions` from the trail).
- **Camera:** set `camera.viewfinder.zoom < 1` to fit most of the active set. Replace auto-follow-player with **user drag-to-pan**, clamped to world bounds (Flame `DragCallbacks` on the game, or a pan/scroll input component). Avatar movement no longer drives the camera; add only a **gentle nudge** if the avatar would walk off the visible edge.
- **Refit on filter change:** `applyFilter` recomputes the visible-set bounds and adjusts zoom/clamp so the tab's books fill the view.
- Avatar walk + arrival unchanged: `walkToBook` / `_checkBookArrival` fire `arrivedAtBook` → preview modal. Walks are short now (everything on-screen).
- Avatar starts at the scatter centroid on `loadBooks`.
- **Remove** `IsometricGroundComponent` usage. Add a lightweight in-world props layer (below book nodes by priority): reuse `assets/images/CherryTree_Spring.png` as scattered `SpriteComponent`s + a few clouds; deterministic positions so props don't jump. Keep `AmbientParticlesComponent`.

### 3. Backdrop — `lib/src/features/library/library_screen.dart`

- Replace `_RoomBackground` / `_SkyHillsPainter` parallax (synced to `cameraXNotifier`) with a **static `StoriaColors.paper` (warm) backdrop**. No camera sync.
- Remove the `cameraXNotifier`-driven background scroll. `cameraXNotifier` can be removed or reduced if nothing else consumes it (verify the engine adapter + session before deleting).
- Decorative props live in-world (Flame) so they pan/zoom with the map; the Flutter layer is just the flat sky/paper fill behind `GameWidget`.

### 4. Files removed / cleaned

- `isometric_ground_component.dart` — delete (no longer used).
- `map_route_component.dart` — already deleted; stays gone.
- TMX assets (`storia_ground.tmx`) — leave on disk but unreferenced (out of scope to purge).

## Data flow

```
books + viewport ──► LibraryMapLayout.build() ──► 2D scatter positions (stable)
                                                      │
                          ┌───────────────────────────┤
                          ▼                           ▼
            LibraryGame.loadBooks()          adapter visible-id math
              · place nodes                  · computeVisibleIds (2D)
              · place props (below)
              · avatar at centroid
              · zoom-to-fit
                          │
   tap book ─► walkToBook ─► arrival ─► arrivedAtBook ─► preview modal
   drag ────► pan camera (clamped)
   tab change ► applyFilter ─► hide non-matching + refit zoom/bounds
```

## Testing

Update the ~8 touched tests; key cases:

- **Layout:** scatter is deterministic (same input → same positions), respects min spacing (no overlaps), world bounds enclose all nodes.
- **Visibility:** `computeVisibleIds` correct in 2D for a given camera rect.
- **Game:** tapping a node walks the avatar and fires `arrivedAtBook`; filter hides non-matching nodes; avatar starts at centroid.
- **Camera:** pan clamps to world bounds; refit covers the visible set after a filter change.
- Files: `flame_library_map_engine_adapter_test.dart`, `library_map_layout_test.dart`, `library_map_event_test.dart`, `library_map_session_test.dart`, `library_map_screen_test.dart`, `player_movement_test.dart`, `map_filter_components_test.dart`, `fakes/fake_ports.dart`.

## Out of scope

- New illustrated art assets (using existing tree/cloud assets).
- Themed regions / clustering by genre.
- Re-introducing any reading-order gating or a journey destination.
- Purging unused TMX files from the repo.

## Ponytail notes

- Reuse existing `CherryTree_Spring.png` + cloud painters for props — no new art.
- Static backdrop instead of parallax — deletes the `cameraXNotifier` sync path rather than extending it to 2D.
- Deterministic seeded scatter — no persistence of positions needed; recomputed cheaply, stable by construction.
