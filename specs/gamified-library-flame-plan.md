# Gamified Library — Adventure Map Implementation Plan

Generated: 2026-04-02

## Goal

Replace the current shelf-based / free-roam library concept with a **horizontally scrolling, node-based adventure map** for book selection.

The new experience should feel like a **classic mobile game world map**:
- a primary avatar travels between authored destination nodes
- each destination represents a book
- the map is scenic and readable first, lightly literary second
- the UI supports browsing books in a playful way without turning the library into a progression-locked campaign

---

## Final Direction (Agreed)

| Decision | Choice |
|---|---|
| Core interaction model | **Node-based world map** |
| Movement | Avatar follows authored routes between nodes |
| Map framing | Horizontally scrolling map |
| Avatar role | **Primary** |
| Emotional framing | Character-led adventure; books are level-like destinations |
| Destination meaning | **Level marker** more than literal story diorama |
| Node density | ~10–12 total node slots, ~4–5 visible per viewport |
| Node hierarchy | No hero-node system in v1 |
| Node style | One consistent node family with small variations |
| Cover usage | Cover image integrated into node marker, medium prominence |
| Map style | Mixture of scenic landscape + authored game-map composition |
| Route style | Explicit connected route, Prism-Plains-style readability |
| Book theming in environment | Light only |
| Search / filter | Hybrid: stable map + some dynamic node response + secondary browse UI |
| Preview behavior | Anchored floating card near node |
| Travel speed | Moderate |
| Preview timing | If near/current node, open quickly; otherwise travel first |
| During travel | Same-node repeat tap preserves intent; different-node tap reroutes immediately |
| On dismiss preview | Avatar stays at the node |

---

## Reference Direction

Primary inspiration shifted away from:
- free-roaming bookshelf room
- literal walkable book-world terrain
- dense story diorama

Primary inspiration now is closer to:
- **classic side-scrolling level-select maps**
- **Duolingo-style readable destination markers**
- **Prism Plains-style explicit route clarity**

Visual takeaway:
- **map readability first**
- **avatar journey second**
- **book identity concentrated in nodes and preview UI**
- **background remains open, scenic, and uncluttered**

---

## Experience Summary

The user enters a side-scrolling adventure map.

A character stands at the most recently visited node. The map contains a clear route with connected destination stops. Each stop is a stylized node representing a book. Tapping a node sends the avatar along the path to that destination. On arrival, a lightweight preview card appears. The user can then open the book.

This should feel like:
- browsing through a playful reading world
- traveling across a curated game map
- selecting books through destinations rather than shelves

This should **not** feel like:
- a free-movement platformer
- a literal library room
- a progression-heavy campaign with hard locks
- a full story diorama per book

---

## Revised Product Principles

### 1. The avatar is the star
The character is not decorative garnish. The map should be composed around the character’s journey between destinations.

### 2. The map is browseable, not restrictive
The map may visually imply guidance, but it should not strongly gate exploration in v1.

### 3. The route must be obvious
Users should immediately understand where the avatar can travel.

### 4. Nodes carry book identity
The environment stays light and readable. Books are primarily expressed through node markers and the preview overlay.

### 5. Consistency beats spectacle
Avoid a hero-node system for v1. Use a stable, repeatable destination marker language.

---

## World / Map Structure

### Layout
- One horizontally scrolling world
- Approx. **10–12 total node slots** across the map
- Approx. **4–5 node opportunities** visible per viewport
- Mostly active nodes, with **1–2 breathing spaces** for pacing
- Breathing spaces can contain small avatar-centric rest beats (bench, signpost, little pause area), but not new gameplay systems

### Background
The background should be:
- scenic
- open
- bright
- easy to read
- composed for nodes and routes

The background should **not** be:
- dense
- heavily book-built
- crowded with literary props
- visually louder than the route/nodes

### Route
The map route should be:
- explicit
- connected
- visually legible at a glance
- suitable for authored movement paths

Recommended route treatment:
- visible road/path base
- dotted or highlighted connection treatment on top
- classic level-map clarity

### Book identity in environment
Keep environmental book theming light.

Strongest book identity should live in:
1. nodes
2. preview card
3. subtle supporting accents

---

## Node Design System

### Node role
Each node represents a book as a **level-like destination marker**.

Nodes should feel like:
- compact adventure-map destinations
- readable level stops
- lightly storybook-flavored markers

Nodes should **not** feel like:
- giant literal books standing in the world
- raw thumbnails pasted onto terrain
- big custom scenic dioramas
- heavily hierarchical “hero” monuments

### Node family
Use **one consistent node family** in v1.

Variation should come from:
- the inserted cover image
- subtle accent color changes
- very small ornament differences only

Avoid:
- hero nodes
- bespoke per-book landmarks
- multiple large template classes in v1

### Node visual language
Node base style:
- **hybrid of pedestal/plaque + small ornament/structure**
- compact silhouette
- readable at small mobile size
- roughly equal visual importance across all nodes

### Cover treatment
- Real `coverUrl` artwork is integrated into the node
- Cover appears in a **rounded-rectangle inset**
- Cover prominence is **medium**
- Node remains visually primary; cover remains clearly recognizable but secondary

### Color treatment
- Base structure remains consistent
- Accent palette can shift subtly per book/category/query state
- Avoid loud rainbow variation across all nodes

### Node socket / destination pad
Each node should sit on a small embedded destination base or pad.

This supports:
- route readability
- avatar arrival readability
- a consistent authored map look

---

## Avatar Behavior

### Role
The avatar is primary and should remain central to the feel of the screen.

### Animation
Use the **existing idle / running animation system** already built in `PlayerComponent`.

Sprite normalization and cleanup are acknowledged as a separate follow-up task, not part of this visual/product pivot.

### Resting state
When the map opens, the avatar should rest at the **most recently visited node**.

### Arrival position
The avatar should read as being **at the node** (classic level-map style), not loosely standing beside it.

Design implication:
- the node art should support some overlap with the character
- the character should still remain readable when on the destination pad

---

## Interaction Model

### Tap behavior
#### If the tapped node is already nearby/current
- preview can open quickly/immediately

#### If the tapped node is farther away
- avatar travels first
- preview opens on arrival

### Same-node repeated tap during travel
- preserve user intent
- open preview as soon as the avatar reaches the node

### Different-node tap during travel
- reroute immediately to the new node

### Dismiss behavior
When the floating preview is dismissed:
- avatar remains at the current node
- map stays where it is
- no automatic return movement

---

## Camera Behavior

### Overall framing
- Horizontally scrolling map
- Camera follows the avatar during travel
- The journey should be visible enough to feel meaningful, but not so slow that browsing becomes tedious

### Travel speed
Use a **moderate** travel feel:
- short moves feel quick
- longer moves are still animated and visible
- travel should not become a delay tax on selection

Potential future polish:
- slightly compress duration for very long-distance travel
- preserve authored path-following while improving responsiveness

---

## Preview UI

### Presentation
Use a **floating preview card anchored near the node**.

This preserves:
- map visibility
- avatar-to-node relationship
- a game-like feel instead of switching into heavy app-mode UI

### Content level
Use **light metadata**:
- cover
- title
- author
- one lightweight secondary detail (e.g. reading band or pages)
- primary CTA: `Read`

Avoid turning the anchored preview into a large modal detail sheet.

---

## Search / Filter Strategy

The old shelf model assumed search/filter directly determined visible shelf items. That is no longer the case.

### New behavior
Use a **hybrid** approach:
- stable authored map structure remains intact
- some dynamic node content can respond to filter/search
- broader query results appear in a secondary browse layer / panel / overlay

This preserves:
- map composition
- avatar route consistency
- curated readability

while still letting search/filter meaningfully affect discovery.

---

## Technical Architecture

## Core concept change
The biggest technical shift is:

### Old concept
- free movement on a walkable plane
- arbitrary world-space tapping
- shelves / books as spatial scene objects

### New concept
- authored node graph or ordered route
- avatar moves between known destinations
- book selection is destination-based, not terrain-based

This should simplify implementation.

---

## Proposed File Responsibilities

### `lib/src/features/library/library_screen.dart`
Responsibilities:
- host the map `GameWidget`
- host floating search/filter controls
- host preview overlay card
- bridge map selection state with Flutter navigation
- coordinate secondary browse UI for broader search/filter results

### `lib/src/features/library/game/library_game.dart`
Responsibilities:
- manage map world size
- manage route/path data
- manage node positions and authored destination sockets
- manage camera following
- manage avatar movement between nodes
- emit selected/arrived book events to Flutter

### `lib/src/features/library/game/player_component.dart`
Responsibilities:
- keep current idle/running behavior
- follow authored destination path
- remain the main movement/readability anchor

### Replace / rethink `book_shelf_component.dart`
The shelf concept no longer matches the product direction.

Replace with something like:
- `map_book_node_component.dart`
- `book_destination_component.dart`
- `library_map_node_component.dart`

Responsibilities:
- render consistent node marker
- display cover inset
- support selected / focused state
- define avatar arrival anchor
- expose tap target for movement/selection

### Background / route components
Potential new supporting components:
- `map_route_component.dart`
- `map_socket_component.dart`
- `map_rest_stop_component.dart`
- `map_background_layers.dart`

Depending on implementation split, these can live in Flame or partially in Flutter.

---

## Data Model Additions (Conceptual)

Likely map-facing data needed per node slot:
- node id
- optional associated `Book`
- world position
- path adjacency or ordered route relationship
- whether node is dynamic vs stable slot
- optional accent color / node styling metadata
- avatar arrival point

Potential conceptual model:

```dart
class LibraryMapNode {
  final String id;
  final Vector2 position;
  final Book? book;
  final bool isDynamicSlot;
  final Color? accentColor;
  final Vector2 avatarStandPosition;
}
```

Exact model shape can evolve later.

---

## Movement / Pathing Model

The map does not need free pathfinding.

Instead:
- authored node positions
- authored visible route
- movement along known route segments

Possible implementation simplifications:
1. ordered horizontal route with interpolated movement
2. pre-authored path polyline between nodes
3. simple segment-following between neighboring nodes

For v1, prefer the simplest authored-path approach that visually matches the route.

---

## Rendering Strategy

### Background
Can remain mostly Flutter-rendered or be split into lightweight Flame background layers.

Priority:
- scenic readability
- low complexity
- easy iteration

### Nodes
Nodes are best handled inside the game layer so they can:
- align with route positions
- coordinate with avatar movement
- participate in camera/world logic

### Preview UI
Keep preview in Flutter.

### Search/filter UI
Keep search/filter in Flutter.

---

## Recommended Phase Plan

### Phase 1 — Map Foundation
Goal: replace shelf-room concept with a scrolling map shell.

1. Remove shelf-room assumptions from layout
2. Create scenic horizontal map background
3. Define world width and viewport density for ~10–12 node slots
4. Add explicit route rendering / route placeholders
5. Replace shelf placement with authored destination positions

Acceptance:
- the library renders as a scrolling game map
- route is readable
- placeholder destination slots appear in authored positions

### Phase 2 — Node System
Goal: replace shelf books with map nodes.

1. Build a consistent destination marker component
2. Add rounded-rect cover inset using `coverUrl`
3. Add node accent color support
4. Add destination pads / sockets beneath nodes
5. Support tap targeting and selected state

Acceptance:
- books appear as compact level-like nodes
- nodes are readable and visually consistent
- cover art is integrated but not dominant

### Phase 3 — Avatar-Led Travel
Goal: switch from arbitrary tap-to-move to node travel.

1. Keep existing player idle/running sequence
2. Add movement between nodes along authored route
3. Store most recently visited node
4. Make camera follow avatar during travel
5. Support rerouting behavior

Acceptance:
- tapping a node sends the avatar there
- avatar remains primary in the experience
- travel is smooth and moderate in duration

### Phase 4 — Preview + Read Flow
Goal: restore book selection UX.

1. On arrival, show anchored floating preview card
2. Include title, author, cover, lightweight secondary metadata, CTA
3. Dismiss without moving avatar away
4. Keep navigation to `/reader/:bookId` in Flutter

Acceptance:
- avatar arrives at node
- preview appears near node
- user can open reader or dismiss naturally

### Phase 5 — Search / Filter Hybridization ✅ Completed
Goal: reconcile the map with discovery UI.

Implemented:
1. The authored map layout stays stable during search and filtering
2. Matching books remain emphasized on the map while non-matching nodes dim in place
3. A secondary browse panel surfaces broader results without reflowing the map
4. Browse results can guide the avatar to a destination node on the existing route

Delivered behavior:
- search/filter still works
- map remains coherent
- world does not fully reshuffle on every query
- search uses a short debounce for smoother updates

### Phase 6 — Polish ✅ Completed
Goal: bring the map to life.

Implemented polish:
- route glow / travel highlights
- subtle ambient particles
- light node focus treatment for selected and arrival states
- smoother camera easing while following avatar movement
- arrival emphasis when reaching a destination node
- improved node shadows and grounding

Still intentionally deferred:
- full sprite normalization pipeline
- heavy progression systems
- bespoke landmark system per book
- richer travel FX/audio and environmental props

---

## What Is Explicitly No Longer In Scope

The following ideas were considered but are **not** the chosen v1 direction:
- shelf-based room browsing
- free-roaming floor taps anywhere in the world
- dense walkable bookscape terrain
- giant per-book diorama scenes
- true isometric gameplay conversion
- hero-node hierarchy
- strong lock/completion/progression UI state on every node

---

## Open Areas For Future Iteration

These can be revisited later after the core map works:
- node state visuals (current, recent, recommended, completed)
- richer map regions/themes
- more dynamic node-slot logic
- stronger environmental literary accents
- alternate map skins
- avatar customization
- travel FX/audio beyond the current visual route highlighting
- sprite normalization cleanup and deeper avatar animation polish

---

## Implementation North Star

Build the library chooser like a **readable, horizontally scrolling adventure map** where:
- the character is central
- books are level-like destinations
- the path is explicit
- nodes are consistent and elegant
- the world is scenic and uncluttered
- reading identity is present, but lightly layered into a game-map structure

If any design or engineering decision conflicts with this, prefer:
1. route readability
2. avatar clarity
3. node consistency
4. fast browsing UX
5. light literary flavor over heavy thematic complexity

---

## Asset Strategy — Programmatic Rendering (No Raster Assets)

All map visuals are rendered programmatically using Flutter `CustomPainter` / Flame `Canvas` APIs. The only raster assets remain the existing avatar spritesheets (`idle.png`, `running.png`). Book covers load at runtime from `coverUrl`.

This decision keeps the asset footprint near zero, enables fast iteration without an art pipeline, and stays consistent with the existing architecture decision (Flutter background + Flame overlay).

---

### Background Layers

Three parallax layers rendered via `CustomPainter` in the Flutter background widget (replacing current `_RoomDecoration`).

#### Sky layer (parallax 0.2x)
- Full-height vertical `LinearGradient`: light sky blue (#B3E5FC) at top → warm peach (#FFE0B2) at horizon (~60% height)
- 2–3 soft elliptical cloud shapes via `Canvas.drawOval` with white at 15–25% opacity
- Optional: gentle sine-wave cloud drift using elapsed time

#### Hills layer (parallax 0.5x)
- 2–3 overlapping bezier curves (`Canvas.drawPath` with `Path.quadraticBezierTo`) filled with muted greens
- Back hills: darker muted sage (#A5D6A7 at 60% opacity), taller, smoother curves
- Front hills: lighter green (#C8E6C9 at 80% opacity), lower, more rolling
- Hills span `worldWidth * 1.5` to prevent edge gaps during parallax

#### Ground layer (parallax 1.0x — locked to camera)
- Flat ground plane from ~70% screen height to bottom
- Warm earth tone fill: `LinearGradient` from light tan (#D7CCC8) to warm brown (#BCAAA4)
- Subtle horizontal ground line at the top edge (1.5px, #8D6E63 at 40% opacity)
- Optional: faint grass tufts as small `Canvas.drawLine` clusters at ground line

---

### Route / Path

Rendered as a Flame `PositionComponent` using `Canvas.drawPath` with `PathMetrics` for dashing.

#### Route base
- Authored polyline connecting all node positions in order (straight segments with slight vertical wander)
- Stroke: warm brown (#8D6E63), 6px width, `StrokeCap.round`
- Sits at ground level (~72% screen height with vertical variation per node)

#### Route dash overlay
- Same path, stroked with dashed pattern using `PathMetrics.extractPath`
- Dash: 12px on, 8px off
- Color: lighter tan (#D7CCC8) at 70% opacity, 3px width
- Creates a dotted-trail-over-dirt-road look

#### Route implementation
```dart
// Pseudocode for dashed path
final pathMetrics = path.computeMetrics();
for (final metric in pathMetrics) {
  double distance = 0;
  while (distance < metric.length) {
    final end = (distance + dashLength).clamp(0, metric.length);
    canvas.drawPath(metric.extractPath(distance, end), dashPaint);
    distance += dashLength + gapLength;
  }
}
```

---

### Node Pedestal (MapBookNodeComponent)

Each node is a Flame `PositionComponent` (~80x110 logical pixels) rendered via `Canvas`.

#### Destination pad (bottom layer)
- `Canvas.drawOval`: horizontal ellipse beneath the pedestal
- Size: 90x24, centered under the node
- Fill: radial gradient from #8D6E63 (center, 30% opacity) to transparent
- Grounds the node visually on the path

#### Pedestal base
- `Canvas.drawRRect`: rounded rectangle, 70x90
- Fill: warm cream (#FFF8E1) with 1.5px border (#D7CCC8)
- Corner radius: 10px
- Subtle drop shadow: `MaskFilter.blur(BlurStyle.normal, 3)` in #000000 at 15% opacity, offset (0, 2)

#### Cover inset
- `Canvas.drawRRect`: rounded rectangle inset within pedestal
- Position: centered horizontally, 8px from top
- Size: 54x54, corner radius 6px
- If cover loaded: draw `Sprite` clipped to this rect
- If loading: pulse opacity 0.5–1.0 on cream fill (same shimmer as current `BookShelfComponent`)
- If no cover: draw placeholder book icon (two small rects + spine line, same as current)

#### Title bar
- Below the cover inset, 4px gap
- `Canvas.drawParagraph`: book title, max 1 line, ellipsis overflow
- Font: 9px, #5D4037 (dark brown), center-aligned
- Width constrained to 58px

#### Accent stripe
- Thin horizontal bar (54x3) at bottom of pedestal, 6px from bottom edge
- Color: per-node `accentColor` (defaults to #FFB74D warm amber)
- Rounded caps via `StrokeCap.round`

#### Selected / focused state
- Outer glow: `Canvas.drawRRect` with `MaskFilter.blur(BlurStyle.normal, 8)`
- Color: accent color at 35% opacity
- Drawn behind the pedestal, 4px larger on each side

#### Dimmed state (filtered out)
- All paints multiplied by 0.25 opacity (same approach as current `BookShelfComponent`)

---

### Rest Stop Props (Optional — Post-Phase-6)

Small canvas-drawn decorative elements placed at breathing-space positions on the route.

#### Signpost
- Vertical line: 2px wide, 40px tall, #6D4C41
- Two angled rectangles at top: 20x8 each, rotated ±15°, #8D6E63 fill
- Positioned at authored rest-stop coordinates

#### Bench
- Seat: `Canvas.drawRRect` 30x6, #8D6E63
- Two legs: `Canvas.drawLine` 2px, 12px tall, #5D4037
- Simple silhouette, no detail needed

These are low priority and can be skipped entirely for v1.

---

### Color Palette Summary

| Token | Hex | Usage |
|---|---|---|
| `skyTop` | #B3E5FC | Sky gradient top |
| `skyHorizon` | #FFE0B2 | Sky gradient bottom / horizon |
| `cloudWhite` | #FFFFFF @ 20% | Cloud ovals |
| `hillBack` | #A5D6A7 @ 60% | Back hills fill |
| `hillFront` | #C8E6C9 @ 80% | Front hills fill |
| `groundLight` | #D7CCC8 | Ground top |
| `groundDark` | #BCAAA4 | Ground bottom |
| `groundLine` | #8D6E63 @ 40% | Ground edge line |
| `routeBase` | #8D6E63 | Route path stroke |
| `routeDash` | #D7CCC8 @ 70% | Route dash overlay |
| `pedestalFill` | #FFF8E1 | Node pedestal background |
| `pedestalBorder` | #D7CCC8 | Node pedestal border |
| `pedestalShadow` | #000000 @ 15% | Node drop shadow |
| `titleText` | #5D4037 | Node title text |
| `accentDefault` | #FFB74D | Default accent stripe / glow |
| `padCenter` | #8D6E63 @ 30% | Destination pad center |
| `glowSelected` | accent @ 35% | Selected node glow |
| `propWood` | #6D4C41 | Rest stop prop dark |
| `propWoodLight` | #8D6E63 | Rest stop prop light |

---

### What This Replaces

| Current File | Current Role | New Role |
|---|---|---|
| `_RoomDecoration` in `library_screen.dart` | Wall gradient, shelf planks, floor, vignette | Sky/hills/ground parallax painter |
| `BookShelfComponent` | Rectangular book on shelf | `MapBookNodeComponent` pedestal with cover inset |
| Shelf plank rendering | Horizontal line beneath books | Route path + destination pads |
| Warm vignette blob | Decorative wall circle | Removed (clouds serve similar purpose) |

### What Stays The Same

| Asset | Reason |
|---|---|
| `idle.png` (1x3 spritesheet) | Avatar idle poses — already working |
| `running.png` (5x5 spritesheet) | Avatar run cycle — already working |
| `AmbientParticlesComponent` | Floating dust motes — still fits the map feel |
| Cover images from `coverUrl` | Loaded at runtime via `ResilientCacheManager` — no change |
