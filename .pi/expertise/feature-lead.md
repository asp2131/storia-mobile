# Feature Lead — Mental Model

> Auto-evolving expertise file. Updated by self-improver after each task cycle.
> Token budget: 7K max.

## Proven Patterns

<!-- Patterns confirmed to work well -->

## Anti-Patterns

<!-- Approaches that caused issues -->

## Conventions Discovered

- Riverpod for all shared state
- Ports/adapters pattern in reader feature
- Services handle side effects, providers expose reactive state
- Feature dirs: data/, domain/, presentation/ when applicable

## Gotchas

- Flame API: Use HasGameReference<T> mixin + game.images, NOT deprecated gameRef
- SpriteAnimationTicker for reset()/done(), not SpriteAnimation directly
