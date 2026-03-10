# Superdesign Intro + Auth Implementation Plan

Project ID: `0eff44ae-60e8-4b45-96b5-b986dbd58674`

## Source Drafts Reviewed

- Intro / onboarding: `0807975e-8bde-4890-86bc-54c057440a90`
- Sign in: `0f563af3-e757-41d0-bf15-644cbede2726`
- Library style reference: `8dea452a-0de2-4afa-b80e-812066a3daf9`
- Reader style reference: `bc8332b9-6414-41bb-abd6-2ca8dd603558`

## Shared Design Language Extracted From The HTML

### Typography

- Display serif: `Lora`
- UI/body font: `Nunito`
- Titles are italic, large, and center-aligned or softly offset.
- Body copy uses rounded, friendly weights with generous line height.

### Core Colors

- Paper background: `#FDFBF7`
- Ink / primary text: `#4A3F35`
- Dusty pink accent: `#D9A0A0`
- Sage accent: `#9DB096`
- Mustard accent: `#E5C158`
- Reader dark surface: `#12161A` / `#1D2127`

### Motifs

- Watercolor paper texture overlay
- Large blurred organic blobs behind content
- Irregular "sketch" borders with hand-drawn radius shapes
- Soft floating or breathing motion on hero artwork and cards
- Rounded pill controls and lightly elevated paper cards
- Child-facing illustration area paired with parent-trust messaging

### Component Patterns Reused Across Drafts

- Floating watercolor background layer
- `sketch-border` primary CTA shape
- `sketch-border-subtle` for cards, inputs, and secondary chrome
- Leaf accent / decorative flourish
- Parent safety trust box
- Header pills for navigation and utility actions

## Current Codebase Assessment

- App shell is already set up with Riverpod and `GoRouter`.
- `supabase_flutter` is installed, but there is no auth flow or auth state provider wired into routing.
- [`lib/src/routing/app_router.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/routing/app_router.dart) currently boots directly into `/library`.
- [`lib/src/core/theme/app_theme.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/core/theme/app_theme.dart) still uses seed-based Material defaults plus `Inter`, which conflicts with the drafts.
- [`lib/src/features/library/library_screen.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/features/library/library_screen.dart) and [`lib/src/features/reader/reader_screen.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/features/reader/reader_screen.dart) already contain custom UI, so the new intro/auth work should establish reusable primitives instead of building isolated screens.
- `lib/src/features/auth/` exists but is empty, which is the right place to land the new flow.

## Proposed Implementation Scope

### Milestone 1

- Intro / onboarding entry screen based on the watercolor owl draft
- Sign in screen based on the provided auth draft
- Sign up screen derived from the sign-in layout and styling
- Forgot password / recovery screen derived from the same auth shell
- Router gating so signed-out users see intro/auth first

### Milestone 2

- Restyle library to match the fetched library draft using the same primitives
- Align reader chrome with the immersive reader draft without regressing current audio and page logic

## Flutter Architecture Plan

### 1. Design Tokens And Theme

Add a dedicated Storia design layer instead of expanding the current seed theme.

Proposed files:

- `lib/src/core/theme/storia_colors.dart`
- `lib/src/core/theme/storia_text_theme.dart`
- `lib/src/core/theme/storia_spacing.dart`
- `lib/src/core/theme/storia_motion.dart`
- Update [`lib/src/core/theme/app_theme.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/core/theme/app_theme.dart)

Implementation notes:

- Replace `Inter` with `Lora` + `Nunito`.
- Define explicit light tokens instead of relying on `ColorScheme.fromSeed`.
- Keep a dark token subset only for reader surfaces so the existing reader path remains consistent.
- Centralize shadow, blur, border, and radius values used by the sketch-paper style.

### 2. Shared UI Primitives

Create reusable widgets before building screens.

Proposed files:

- `lib/src/core/widgets/watercolor_scaffold.dart`
- `lib/src/core/widgets/paper_texture_overlay.dart`
- `lib/src/core/widgets/watercolor_blobs.dart`
- `lib/src/core/widgets/sketch_card.dart`
- `lib/src/core/widgets/sketch_button.dart`
- `lib/src/core/widgets/sketch_icon_button.dart`
- `lib/src/core/widgets/sketch_text_field.dart`
- `lib/src/core/widgets/parent_safety_box.dart`
- `lib/src/core/widgets/leaf_accent.dart`

Implementation notes:

- Use `CustomPainter`, layered `Container`s, gradients, and blurred shapes to mimic the HTML background art.
- Do not chase literal SVG parity for every decorative blob on day one; recreate the composition language, not every path.
- The sketch border effect should be one reusable `ShapeBorder` or decoration helper rather than repeated per screen.

### 3. Auth State And Routing

Wire auth before building the screens so navigation flow is real.

Proposed files:

- `lib/src/features/auth/data/auth_repository.dart`
- `lib/src/features/auth/data/auth_providers.dart`
- `lib/src/features/auth/domain/auth_state.dart`
- `lib/src/features/auth/presentation/auth_gate.dart`
- Update [`lib/src/routing/app_router.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/routing/app_router.dart)

Routing changes:

- Add `/intro`
- Add `/sign-in`
- Add `/sign-up`
- Add `/forgot-password`
- Keep `/library`, `/reader/:bookId`, `/settings`
- Change the initial route from `/library` to an auth-aware gate
- Add redirect logic driven by the Supabase session state

Auth behavior:

- Signed out: `/intro` -> `/sign-in` or `/sign-up`
- Signed in: default to `/library`
- Password recovery deep links should land in the recovery flow instead of dumping the user into the library

### 4. Screen Composition

#### Intro Screen

Proposed file:

- `lib/src/features/auth/presentation/intro_screen.dart`

Implementation notes:

- Full-screen watercolor scaffold
- Center hero illustration area with custom painter or local SVG asset
- Bottom paper sheet with title, body copy, trust box, primary CTA, and secondary sign-in link
- CTA should route to sign-up or sign-in based on product decision; default recommendation is sign-up

#### Sign In Screen

Proposed file:

- `lib/src/features/auth/presentation/sign_in_screen.dart`

Implementation notes:

- Reuse watercolor shell with smaller header chrome
- Platform-aware social button treatment
- Email and password inputs with icon-leading sketch fields
- Secondary actions: forgot password, create account
- CTA should call the auth repository and surface inline loading/error states without breaking the visual shell

#### Sign Up Screen

Proposed file:

- `lib/src/features/auth/presentation/sign_up_screen.dart`

Implementation notes:

- Same structure as sign-in
- Swap heading, body copy, CTA label, and footer link
- Support minimum fields first: email + password
- Leave profile enrichment for later, likely in `features/profile`

#### Forgot Password Screen

Proposed file:

- `lib/src/features/auth/presentation/forgot_password_screen.dart`

Implementation notes:

- Single email field, explanatory copy, send-reset CTA
- Keep trust and parent-oriented language from the draft system

## Implementation Sequence

1. Replace theme tokens and fonts so new screens are not built on the current generic Material look.
2. Build the shared watercolor and sketch primitives.
3. Add auth repository/providers and session-driven router redirects.
4. Implement intro screen.
5. Implement sign-in, then derive sign-up and forgot-password from the same shell.
6. Add widget tests for route gating and basic form affordances.
7. After auth is stable, restyle library and reader with the same primitives.

## File-Level Rollout Map

### New Files

- `lib/src/core/theme/storia_colors.dart`
- `lib/src/core/theme/storia_motion.dart`
- `lib/src/core/theme/storia_spacing.dart`
- `lib/src/core/theme/storia_text_theme.dart`
- `lib/src/core/widgets/watercolor_scaffold.dart`
- `lib/src/core/widgets/paper_texture_overlay.dart`
- `lib/src/core/widgets/watercolor_blobs.dart`
- `lib/src/core/widgets/sketch_button.dart`
- `lib/src/core/widgets/sketch_card.dart`
- `lib/src/core/widgets/sketch_icon_button.dart`
- `lib/src/core/widgets/sketch_text_field.dart`
- `lib/src/core/widgets/parent_safety_box.dart`
- `lib/src/core/widgets/leaf_accent.dart`
- `lib/src/features/auth/data/auth_repository.dart`
- `lib/src/features/auth/data/auth_providers.dart`
- `lib/src/features/auth/domain/auth_state.dart`
- `lib/src/features/auth/presentation/intro_screen.dart`
- `lib/src/features/auth/presentation/sign_in_screen.dart`
- `lib/src/features/auth/presentation/sign_up_screen.dart`
- `lib/src/features/auth/presentation/forgot_password_screen.dart`

### Existing Files To Update

- [`lib/src/core/theme/app_theme.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/core/theme/app_theme.dart)
- [`lib/src/routing/app_router.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/routing/app_router.dart)
- [`lib/src/app.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/src/app.dart)
- [`lib/main.dart`](/Users/akinpound/Documents/experiments/storia-mobile/lib/main.dart) if recovery link handling or auth bootstrap requires it

## Risks And Decisions To Resolve Early

- The provided drafts include only sign-in HTML. Sign-up and recovery should intentionally reuse the same shell instead of waiting for separate designs.
- Social auth is platform-sensitive. The draft implies Apple on iOS/macOS and Google elsewhere; that needs to be reconciled with the exact providers enabled in Supabase.
- Decorative SVG fidelity can consume time quickly. The first pass should preserve tone, hierarchy, and motion, not recreate every path by hand.
- The current library and reader UIs already diverge from the draft style. Building shared primitives first avoids duplicating another short-lived visual system.

## Recommended Next Step

Implement Milestone 1 in this order:

1. Theme tokens and primitives
2. Auth repository plus router gate
3. Intro screen
4. Sign-in / sign-up / forgot-password screens

That will give the app a coherent signed-out experience and create the component base needed to restyle library and reader afterward.
