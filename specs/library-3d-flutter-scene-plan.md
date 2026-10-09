# 3D Library — flutter_scene Revamp Plan

Generated: 2026-10-09
Supersedes (visually): `specs/gamified-library-flame-plan.md`
Status: **Proposal — needs sign-off on Open Questions before Phase 1**

## Goal

Replace the 2D Flame adventure map on the library screen with a **3D scene rendered by
[`flutter_scene`](https://pub.dev/packages/flutter_scene)**. A Meshy-generated character
explores a small world. Books float above stone/marble **columns (pedestals)**, slowly
rotating and bobbing. When the child taps a column (or walks up to one), the camera frames
that book and the existing preview card opens.

What stays: search, length filter, browse panel, preview card → `/reader/:id`, parental
gate → settings, day/night toggle. The kid-facing *flow* doesn't change; only the world
it happens in.

---

## Why this is feasible without a rewrite

The library is already split into ports and adapters:

```
LibraryScreen ──► LibraryMapSessionImpl ──► LibraryMapEnginePort
                  (search, filter, preview,     ▲
                   browse results, events)      │ implemented today by
                                                FlameLibraryMapEngineAdapter
```

`LibraryMapEnginePort` (`lib/src/features/library/ports/library_map_session.dart`) has no
Flame types in it. So the plan is:

1. Add a **`SceneLibraryMapEngineAdapter`** that implements the same port using flutter_scene.
2. Keep `LibraryMapSessionImpl`, the ports/events, `BookPreviewOverlay`, `_FloatingControls`
   and `_BrowsePanel` mostly as they are.
3. Choose the engine with a feature flag. Delete Flame only after the 3D path is in
   production.

The port has a few 2D assumptions to generalize (see Phase 2): `cameraXNotifier` (a 1D
scroll value), `nodeXForBook`, and `LibraryMapBook.worldX/worldY`.

---

## Platform / tooling facts (checked 2026-10-09)

| Item | Status |
|---|---|
| flutter_scene version | 0.24.2 (pre-1.0; minor versions can break the API, so **pin an exact version**) |
| Flutter requirement | **3.47 stable or newer** (3.47.1 for desktop release builds). The repo is on Dart `^3.10`, so the SDK constraint and toolchain must be bumped first. |
| Platforms | iOS, Android, macOS, Windows, Linux, **web (WebGL2, no flag)**, so Playwright web proof still works |
| Flutter GPU | Off by default on native platforms. iOS: `FLTEnableFlutterGPU=true` in `ios/Runner/Info.plist`. Android: `io.flutter.embedding.android.EnableFlutterGPU=true` meta-data in `AndroidManifest.xml`. Dev runs: `flutter run --enable-flutter-gpu`. |
| Impeller | Required on native platforms. `AndroidManifest.xml:48` already sets `EnableImpeller`, so check it's `true`. |
| Model import | `dart run flutter_scene:init` adds a **build hook** that converts `assets/**/*.glb` → `.fsceneb` at build time, then load with `loadScene('assets/…glb')`. Runtime alternative: `Node.fromGlbAsset` (slower, no hook). |
| Animation | Skinned meshes + blended clips with per-clip control, which covers idle/walk/run blending |
| Gotcha | Generated `.fsceneb` assets are tied to the engine version. Regenerate after every Flutter upgrade (re-run `init`). |

Repo conventions affected: AGENTS.md says "no codegen." The flutter_scene build hook is an
**asset-pipeline hook, not Dart codegen** (no `build_runner`, no `*.g.dart`), but it is a new
build step, so the ticket should approve it explicitly. Add a `.wolf/cerebrum.md` note.

---

## Asset pipeline (Meshy AI → app)

### Character
1. Generate the character in Meshy (Text/Image → 3D). Use a stylized, kid-friendly prompt
   that matches the Storia watercolor/sketch look. Ask for **low-poly / game-ready**.
2. **Remesh** to a budget: **≤ 15k triangles**, a single material, and one 1024² base-color
   texture (2048² at most). Mobile GPUs and web are the constraint.
3. **Rig + animate** in Meshy (auto-rig humanoid). Export clips named exactly:
   `Idle`, `Walk`, `Run`, `Wave` (on arrival), and optionally `Jump`/`Cheer`.
   If Meshy's clip set is thin, take the rigged GLB into Mixamo or Blender for extra clips,
   then merge the actions into one GLB in Blender.
4. Export **GLB** (embedded textures, Y-up, meters, character ~1.0–1.2 m tall, origin at
   the feet, facing +Z).
5. Optimize: `gltf-transform optimize in.glb out.glb --texture-compress webp` (keep
   skinning, and check that the result still loads in flutter_scene).
6. Drop it at `assets/models/character/storia_explorer.glb`.

### Columns / pedestals
- 2–3 variants (e.g. marble column, mossy stone pillar, tree stump) so the scene doesn't feel
  copy-pasted. **≤ 3k tris each**, sharing one texture atlas if possible.
- The top surface should be flat, with an empty node named `BookAnchor` at the spot where the
  book floats. The code reads that node's transform, so artists can move it without code
  changes.
- `assets/models/columns/column_{marble,stone,stump}.glb`.

### Environment
- One ground/island GLB (`assets/models/world/library_island.glb`): grass, a path, a few
  props. Keep it under 30k tris total. Meshy can make props, and Blender assembles the
  layout.
- Sky: keep the existing Flutter sky gradient + sun/moon (`_SkyPalette`,
  `_SkyDecorations`) behind a **transparent** scene if flutter_scene supports a
  transparent clear (**spike item**). Otherwise use a skybox/gradient dome mesh tinted by
  `_SkyPalette`.

### Books (no Meshy needed)
Books are **generated in code**: a thin box mesh whose front face uses the book's cover image
as its texture (decoded via the existing `ResilientCoverStoreAdapter` / `LibraryMapCoverPort`
→ `ui.Image` → GPU texture). Covers are dynamic data, so we don't author a model per book.
Fallback when a cover is missing: a solid-color spine using `StoriaColors`.

Add `assets/models/` (and its subdirectories) to `pubspec.yaml` `flutter.assets`.

### Total budget (mid-range Android + web)
≤ ~100k tris on screen, ≤ 12 draw-heavy objects visible, ≤ 25 MB of models in the app bundle.
Target 60 fps on iPhone 12 / Pixel 6 and 30+ fps on low-end Android. Measure in Phase 1.

---

## Scene design

- **Layout**: columns arranged along a gentle **winding path** (spline) around the island,
  not a grid. This keeps the "journey" feel of the current map. Spacing ~2.5 m. Keep
  ~10–12 slots, as the old plan did; with more books, extend the path or page with
  "next island."
- **Camera**: third-person, slightly elevated (~35°), following the character with damping.
  Drag pans/orbits within limits. Pinch zoom is clamped. On book select, the camera dollies
  to frame the column + book.
- **Floating book**: hovers ~0.3 m above `BookAnchor`, with a sine bob (±5 cm, ~2.5 s) and
  a slow Y-rotation. Selected book: scale 1.15, faces the camera, soft glow/emissive tint.
- **Filter response**: books that don't match the query sink into their column and desaturate
  (lerp scale/alpha over `StoriaMotion` durations). Matches rise back up. This replaces
  `applyFilter` dimming.
- **Character**: tap a column → walk along the path spline to it (blend `Idle→Walk→Idle`)
  → `Wave` on arrival → emit `LibraryMapBookArrived` → preview opens. Keep the existing
  rules: tapping the same node again keeps the current intent, and tapping a different node
  reroutes immediately.
- **Day/night**: drive the light direction/color and ambient from `_SkyPalette.isNight`.

---

## Code architecture

```
lib/src/features/library/
  adapters/
    flame_library_map_engine_adapter.dart        (kept until removal phase)
    scene_library_map_engine_adapter.dart        NEW — implements LibraryMapEnginePort
  scene/                                          NEW — all flutter_scene code lives here
    library_scene.dart          Scene root, render loop ticker, lights, camera rig
    library_scene_widget.dart   Widget that hosts the scene (replaces GameWidget)
    character_controller.dart   Spline-following, animation-state machine (pure logic + node)
    column_node.dart            Column + floating book node, bob/rotate/sink tweens
    book_mesh.dart              Procedural book box + cover texture upload
    scene_camera_rig.dart       Follow / focus / orbit-clamp
    scene_picking.dart          Tap → ray → column hit test (ray vs. bounding sphere/AABB)
    scene_assets.dart           Preload/cache GLBs; fallback primitives if load fails
  core/
    library_path_layout.dart    NEW — pure: books → 3D slots along a spline (unit-tested)
```

Rules:
- No flutter_scene imports outside `scene/` and `scene_library_map_engine_adapter.dart`
  (same isolation as Flame has today).
- Keep game logic (path layout, character state machine, picking math, filter tweens) in
  **pure Dart classes** so it can be unit-tested without a GPU.
- Use `flutter_riverpod` 2.x with hand-written providers, plus a `libraryEngineKindProvider`
  (`flame | scene`) for the flag. No codegen.

### Port changes (Phase 2)
Generalize, while keeping the Flame adapter compiling:
- `cameraXNotifier` → keep it, and add `ValueListenable<int> get frameTick` (or
  `viewChanged`). The overlay only uses `cameraXNotifier` to rebuild when the view moves,
  so either one works.
- `screenPositionOfBook` → in 3D, project the book's world position through the camera's
  view-projection matrix to screen space. The preview card anchors to this, so
  `_overlayPosition` keeps working. Also handle "behind camera / off screen".
- `nodeXForBook` → deprecate. The session should only need "does this book have a node."
- `LibraryMapBook.worldX/worldY` → leave them as layout-agnostic metadata, or move them
  into the adapters. Check `library_map_session_impl.dart` for uses.

---

## Phases

### Phase 0 — Toolchain + spike (1–2 days, throwaway branch)
- Bump Flutter to ≥ 3.47.1 and update the `environment.sdk` constraint. Run `./bin/verify.sh`
  to confirm nothing else breaks (watch the `flame_tiled` ↔ `archive` pin in pubspec).
- Add `flutter_scene` (exact pin), run `dart run flutter_scene:init`, enable Flutter GPU in
  Info.plist and AndroidManifest.
- Load a placeholder rigged GLB (e.g. Khronos `Fox.glb`) + 5 cube "columns" on **iOS device,
  Android device, and Chrome**. Measure fps, cold-start load time, and memory.
- Answer: transparent clear over the Flutter sky? Does the per-book cover texture upload
  work on web? Does Playwright capture WebGL2 frames in headless Chromium (may need
  `--use-gl=swiftshader`/`--enable-unsafe-swiftshader`)?
- **Go/no-go gate.** If low-end Android is under 30 fps or web is broken, fall back to the
  "2.5D" option (pre-rendered Meshy character sprite sheets in the existing Flame map).

### Phase 1 — Assets v1 (parallel with Phase 2, art-owner)
- Meshy character (rigged, 4 clips), 2 column variants, island. Run them through the
  budget + optimize steps above. Review in a GLB viewer, then in-app.

### Phase 2 — Engine adapter behind flag
- `library_path_layout.dart` + tests.
- `SceneLibraryMapEngineAdapter` with `loadBooks`, `applyFilter`, `walkToBook`,
  `navigateToBookNode`, `screenPositionOfBook`, `broaderBrowseResults` (reuse the existing
  pure filtering logic and pull it out of `LibraryGame` into `core/` so both adapters share
  it), `arrivedAtBook`, and `dispose`.
- `library_scene_widget.dart` replaces `GameWidget` in `_buildGameView` when the flag is on.
- Lifecycle: copy the Flame adapter's hard-won rules. **Per-screen ownership** and a
  **fresh scene on app resume** (see the comments in `flame_library_map_engine_adapter.dart`
  and `LibraryScreen.didChangeAppLifecycleState`). GPU resources must be released in
  `dispose`.

### Phase 3 — Interaction polish
- Character path-walking + animation blending, camera follow/focus, tap picking, bob/rotate,
  filter sink/rise, day/night lighting, arrival `Wave`, and haptics on select.
- Accessibility: the scene is opaque to screen readers, so add a `Semantics` layer of
  invisible buttons (one per book, labelled with the title) that call `navigateToBook`.
  Respect `MediaQuery.disableAnimations` (no bob, cut the camera instead of flying).

### Phase 4 — Performance + fallback
- Lazy-load cover textures for nearby columns only, and cap texture size (512²).
- Device-capability fallback: if the scene fails to initialize (no Flutter GPU / Impeller,
  old device), automatically use the Flame adapter. This is why Flame stays until Phase 5.
- Profile on low-end Android. Add LOD or reduce shadow quality if needed.

### Phase 5 — Rollout + cleanup
- Flag default → `scene`. After one release with no crash regressions, remove `game/`,
  `flame_library_map_engine_adapter.dart`, and the Flame tests. Drop `flame`/`flame_tiled`
  from pubspec if nothing else uses them, which may also free the `archive` pin.

---

## Testing / verification

- **Unit (no GPU)**: path layout, character state machine (idle→walk→arrive, reroute on a
  different-node tap, same-node tap keeps intent), picking math, screen projection, filter
  state.
- **Session tests**: the existing `library_map_session_test.dart` should run unchanged
  against a fake engine port. That proves the port contract still holds.
- **Widget tests**: `library_map_screen_test.dart` with the engine flag set to a fake that
  doesn't need a GPU (flutter_scene won't render in `flutter test`).
- **Device QA**: iOS + Android physical devices, fps overlay, and background/resume cycle
  (the known Flame blank-screen bug class).
- **Playwright proof** (AGENTS.md): the App Review flow → library, tap a column, the
  character walks, the preview opens, Read → reader. Record at
  `recordings/<ticket>-library-3d.webm`.
- `./bin/verify.sh` green before each handoff.

---

## Risks

| Risk | Mitigation |
|---|---|
| flutter_scene is pre-1.0 and APIs churn | Exact version pin; all usage isolated in `scene/` |
| Flutter 3.47 upgrade breaks other deps | Do it as its own ticket/PR first (Phase 0) |
| Low-end Android perf / thermal | Budgets above, LOD, Flame fallback |
| Meshy topology/rig quality is inconsistent | Remesh + check the rig in Blender; fix clip names before import |
| Build hook adds CI/build time + engine-tied assets | Document in README + cerebrum; regenerate on Flutter bumps |
| Web/headless WebGL for Playwright | Verify in Phase 0; swiftshader flags |
| App size growth | 25 MB model budget, webp textures |
| Kids get lost in free 3D movement | Path-constrained movement, clamped camera, no free-roam |

---

## Open questions (need product/owner answers)

1. **Scope of "most of the library screen":** keep the Flutter search/filter/browse/preview
   UI on top of the 3D scene (recommended), or move those into 3D too?
2. **Movement model:** path-constrained tap-to-walk (recommended, like today), or a
   virtual joystick for free exploration?
3. **Book count:** what is the real expected library size? This decides whether we need
   multiple islands/rooms or paging.
4. **Art direction:** a stylized look matching the watercolor/sketch UI, or more realistic
   Meshy output? (We recommend stylized: flat or toon shading.)
5. **Fallback:** is it OK to keep Flame as the fallback for unsupported devices until the
   3D version is proven?
