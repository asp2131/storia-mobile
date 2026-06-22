# Customizable Character — Design

Date: 2026-06-17
Status: Approved-pending-review
Branch context: replaces the existing `PlayerComponent` on the library map.

## Goal

Replace the library map's flat single-sheet player avatar with a **layered,
fully customizable character** driven by the `Ultimate_Protagonist`
CustomaizableCharacter asset set. Player customizes appearance in an in-app
editor; selection persists to their Supabase profile; the same rig powers
movement and contextual interactions on the library map.

## Source assets (facts)

- Location: `../Ultimate_Protagonist/AnimationSheets/CustomaizableCharacter/`
- **730MB total**, 4,859 PNGs (~154KB avg). Too large to bundle.
- One directory per animation. Each contains every layer × every variant as a
  separate horizontal-grid sheet.
- Frame cell: **460×460 px**. Sheet = `cols × 5 rows`. The **5 rows are facing
  directions** (front → front-¾ → side → ¾-back → back); columns are animation
  frames. Horizontal mirror covers the opposite side (8-way from 5 rows).
  - Idle = 8 cols, Walk = 6, Run = 4, Interact/Sword = 6. (Confirm each anim's
    col count + exact row→direction mapping by frame inspection at impl time.)
- **Layers (z-order bottom→top)** and variant counts (incl. `Blank` = empty slot):
  - L0 Body/skin (6) · L1 Face (5) · L2 BodySuit (16) · L3 Pants (9) ·
    L4 Shoes (6) · **L5 Torso** = Shirt(17)/Dress(17)/Armor(6) *exclusive* ·
    L6 Sleeves (17) · L7 Necklace (5) · L8 Bag (6) · L9 Scarf (6) ·
    L10 Bowtie (5) · **L11 Head** = hair styles (~88) or hats (Beanie/Bamboo/Helmet)
    *exclusive, ~100 options* · **L12 Accessory** = Bow(5)/Horns(4) *exclusive*.

## Scope decisions (locked)

- Customization: **full in-app editor** (every slot + color variant).
- Animations: **non-tool only** — Idle, Walk, Run, Interact, Sit, GetUp.
  Tools are out (reading app, no tools), so all `*HoldingTool`, Dig, Fish,
  Swing, SwordAttack, Damage, Die are excluded.
- Persistence: **Supabase profile**.
- Asset delivery: **Supabase Storage on-demand** + on-device cache. Small
  default outfit bundled for first-run/offline.
  - **Public bucket** name: `character assets` (note the space → `%20` in
    URLs). Assets live under a `CustomaizableCharacter/` prefix folder inside
    the bucket (spelled exactly that way, no 'z'). Full object path:
    `CustomaizableCharacter/<Animation>/<LayerFile>.png`. Example public URL:
    `.../storage/v1/object/public/character%20assets/CustomaizableCharacter/Idle/Layer5_Shirt_Blue.png`.
    With
    **original directory names kept verbatim** (e.g.
    `characters/Run(HoldingToolOrNot)/Layer5_Shirt_Blue.png`). The app must
    **URL-encode** paths — parens → `%28`/`%29`. `Run(HoldingToolOrNot)` is the
    run anim (tool-agnostic, keep it); `Die(HoldingToolOrNot)` is skipped.
  - A JSON **manifest** (anims → layers → variants) is uploaded alongside and
    fetched once; the app does not `list()` the bucket at runtime.

## Decomposition (three sub-projects, built in order)

1. **Layered character renderer + movement** *(this spec)* — drop-in replacement
   for `PlayerComponent`, built against a small bundled default outfit. No
   network. Proves rig, direction logic, movement, contextual anims.
2. **Asset pipeline** — upload library to Supabase Storage as `anim/layer/variant.png`
   + JSON manifest; app downloads only equipped layers for in-use anims, caches
   locally. Replaces the renderer's bundled-default source with the fetched one.
3. **Customization editor + persistence** — slot-based UI honoring exclusive
   slots and `Blank`; writes selection to Supabase profile; drives renderer +
   pipeline.

Each sub-project gets its own spec → plan → implementation cycle. Sub-projects
2 and 3 are sketched here only for boundaries; this document specs **#1** in full.

---

## Sub-project 1 — Layered Character Renderer + Movement (detailed spec)

### Public API (must stay identical — drop-in for `library_game.dart`)

`library_game.dart` consumes only:
`PlayerComponent(startPosition:)`, `targetX` setter, `setWaypoints(List<Vector2>)`,
`isMoving`, `horizontalDirection`, `hasArrived`, `position`.

The new component preserves all of these unchanged. `library_game.dart` should
need **no edits** beyond possibly passing a customization selection.

### Units

1. **`CharacterAnimation` enum** — `idle, walk, run, interact, sit, getUp`.
   (Internal motion states like run-transition/stopping from the old component
   are dropped unless an asset supports them; movement maps directly to
   idle/walk/run.)

2. **`Facing` enum** — `front, frontDiag, side, backDiag, back` (the 5 rows) +
   a `mirrored` bool. A pure function maps a movement velocity vector → nearest
   `Facing` + mirror. Standing still keeps last facing.

3. **`CharacterLayer` enum** — the 13 z-ordered layers (L0..L12), with the
   exclusive-slot collapsing already applied (Torso, Head, Accessory are single
   slots). Carries z-index = render order.

4. **`CharacterSelection`** (value type) — `Map<CharacterLayer, String?>` where
   the value is an asset key (e.g. `"Layer5_Shirt_Blue"`) or `null`/`Blank` for
   empty. A `CharacterSelection.defaults()` returns the bundled default outfit.
   Immutable + `copyWith`. This is the seam sub-projects 2 & 3 plug into.

5. **`LayerSpriteSet`** — given (animation, layer, variantKey), resolves the
   sheet image and slices it into `Facing × frames` `SpriteAnimation`s.
   In #1 the image comes from bundled assets; in #2 from the cache/pipeline.
   This is the **only** unit that knows where bytes come from — isolates the
   pipeline swap.

6. **`PlayerComponent`** (`PositionComponent`, container) —
   - Holds one child `SpriteAnimationComponent` per **visible** layer, added in
     z-order. A layer set to `Blank`/`null` adds no child (or an empty sprite).
   - All children are kept in lockstep: same `CharacterAnimation` + `Facing`.
     Children share one `SpriteAnimationTicker` clock so frames never drift —
     drive children from a single ticker the parent advances in `update`, or
     reset all tickers together on state change. (Decide in plan; single shared
     clock preferred.)
   - `setSelection(CharacterSelection)` rebuilds children (used by editor later;
     in #1 called once at load with defaults).
   - Movement logic (waypoint following, arrival, speed) ported from the current
     `PlayerComponent` verbatim — it already works. Facing now comes from the
     full velocity vector (8-way) instead of horizontal-only flip, but the
     `horizontalDirection`/flip API is preserved for the camera follow code.

### Rendering approach

**Runtime layered children** (chosen). Container + ≤13 child sprite-anims in
lockstep; customization = swap a child's `LayerSpriteSet`. No compositing.
`// ponytail: layered children, bake to one sheet only if a profiler flags draw
calls for a single avatar.`

### Animation/direction lockstep

State change (anim or facing) → for each layer child, set its current
`SpriteAnimation` to `set[animation][facing]` (mirrored via `scale.x = -1` on
the parent, so all layers flip together and stay aligned). One clock advances
all children so multi-layer frames are identical. Mirroring on the parent keeps
layer alignment automatic.

### Default outfit (bundled, sub-project 1 only)

Pick one complete, sensible variant per slot (e.g. Skin1 body, Regular face,
a shirt + pants + shoes + one hair, Blank for the rest) for the anims in scope
(idle/walk/run/interact/sit/getUp). Copy just those sheets into
`assets/characters/default/<anim>/<layer>.png` and add the dir to `pubspec.yaml`.
Estimated footprint: ~6 anims × ~7 non-blank layers × 1 variant ≈ small (<10MB).

### Contextual animations (movement integration)

- idle ↔ walk/run driven by `isMoving` + speed (reuse existing thresholds).
- `interact`: one-shot, triggered when the player arrives at a book node
  (`hasArrived` + pending book target). Returns to idle on completion.
- `sit`/`getUp`: optional trigger points (e.g. a bench/idle-timeout) — wire the
  states + transitions; trigger source can be minimal in #1.

### Error handling

- Missing layer sheet (bad key) → log + skip that layer (character still renders
  from the rest). Never crash the game loop.
- Frame-count/col mismatch → `LayerSpriteSet` validates `image.width % 460 == 0`
  and rows == 5; asserts in debug, falls back to first frame in release.

### Testing (one runnable check per non-trivial unit)

- `Facing` mapping: velocity vectors → expected facing+mirror (pure unit test).
- `CharacterSelection.copyWith`/defaults + exclusive-slot invariant.
- `LayerSpriteSet` slicing: a fixture sheet slices to the right frame counts.
- No widget/golden tests for the live game in #1 unless asked.

### Out of scope for sub-project 1

Network/Storage, the editor UI, persistence, tool anims. Bundled default only.

---

## Open items to resolve at impl time

- Exact row→`Facing` mapping per animation (frame inspection).
- Per-anim column counts (read from each sheet width / 460).
- Whether GetUp is a distinct sheet or reverse-played Sit.
