# Game Builder — Mental Model

> Auto-evolving. Token budget: 7K max.

## Proven Patterns

## Anti-Patterns

## Conventions Discovered

- HasGameReference<T> mixin + game.images (not gameRef)
- Flutter background + Flame overlay architecture
- Camera: edge-triggered at 20% screen edge, not center-locked
- ValueNotifier<double> for Flame/Flutter camera sync
- Only sprites and tap targets in Flame, everything else in Flutter

## Gotchas

- SpriteAnimation has no reset()/done() — use SpriteAnimationTicker via animationTickers[state]
- Sprite sheets in assets/images/, must declare assets/images/ in pubspec.yaml
