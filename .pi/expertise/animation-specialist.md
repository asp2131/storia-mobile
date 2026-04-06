# Animation Specialist — Mental Model

> Auto-evolving. Token budget: 7K max.

## Proven Patterns

## Anti-Patterns

## Conventions Discovered

- Implicit animations for simple state changes
- Keep UI feedback under 300ms, transitions under 500ms
- Respect MediaQuery.disableAnimations
- Sprite sheets: 5x5 grid, SpriteAnimationGroupComponent
- Transition flow: idle → transition → run loop → stopping → idle

## Gotchas

- SpriteAnimationTicker for reset()/done(), NOT SpriteAnimation directly
- Always dispose AnimationControllers in dispose()
