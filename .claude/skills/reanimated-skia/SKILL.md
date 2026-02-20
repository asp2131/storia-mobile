---
name: react-native-skia-reanimated
description: Use this skill when building React Native apps with @shopify/react-native-skia for 2D graphics and react-native-reanimated v4 for animations. Triggers include any mention of Skia canvas, GPU-accelerated graphics, custom drawing, shaders, path animations, gesture-driven Skia animations, particle systems, or combining Reanimated shared values with Skia components. Also use for image filters, blur effects, gradient animations, runtime shaders (SKSL), path morphing, or any Canvas-based animation in React Native. Use when building visual effects, custom charts, animated illustrations, paint/drawing apps, or game-like UIs in React Native.
---

# React Native Skia + Reanimated v4

Build high-performance, GPU-accelerated 2D graphics with smooth animations in React Native.

## Version Requirements

- `react-native` >= 0.79 with **New Architecture (Fabric)** enabled
- `react` >= 19
- `@shopify/react-native-skia` >= 2.x (current: ~2.4)
- `react-native-reanimated` >= 4.x (requires New Architecture, dropped Legacy/Paper)
- `react-native-gesture-handler` >= 2.x (for gesture-driven animations)
- `react-native-worklets` (extracted from Reanimated 4 — installed automatically as dependency)
- iOS 14+, Android API 21+ (API 26+ for video support)

## Installation

```bash
# Core packages
npx expo install @shopify/react-native-skia react-native-reanimated react-native-gesture-handler

# Or with npm/yarn
npm install @shopify/react-native-skia react-native-reanimated react-native-gesture-handler
```

### Expo Quick Start
```bash
npx create-expo-app my-app -e with-skia
```

### Babel Configuration (Reanimated v4)
In `babel.config.js`, use the new worklets plugin:
```js
module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'], // handles reanimated plugin automatically
    // If NOT using Expo, add manually:
    // plugins: ['react-native-worklets/plugin'],
  };
};
```

> **Reanimated v4 Note**: The Babel plugin moved from `react-native-reanimated/plugin` to `react-native-worklets/plugin`. Expo's preset handles this automatically.

---

## Architecture Overview

### How Skia + Reanimated Work Together

React Native Skia **natively accepts Reanimated shared values as props**. No `createAnimatedComponent` or `useAnimatedProps` needed. This is the key integration advantage:

```tsx
// ✅ Direct shared value usage — the Skia way
<Circle cx={sharedX} cy={sharedY} r={sharedRadius} color="cyan" />

// ❌ NOT needed with Skia (this is for regular RN views)
// const AnimatedCircle = Animated.createAnimatedComponent(Circle);
```

### Animation Systems in Reanimated v4

Reanimated 4 provides **two animation systems**:

1. **CSS Animations & Transitions** (NEW in v4) — declarative, state-driven
   - Best for: showing/hiding, expanding/collapsing, simple state transitions
   - Applied via `style` prop with `transitionProperty`, `animationName`, etc.
   - **Not applicable to Skia Canvas components** (Skia doesn't use RN style system)

2. **Shared Values + Worklets** (classic approach) — imperative, frame-level control
   - Best for: gesture-driven, scroll-driven, Skia canvas animations, complex orchestration
   - **This is what you use with Skia**

### Thread Model

```
JS Thread          → React rendering, state updates
UI Thread          → Reanimated worklets, shared value updates, Skia drawing
GPU                → Skia rendering (Metal on iOS, OpenGL/Vulkan on Android)
```

Shared values live on the UI thread. Skia reads them directly during draw — zero bridge overhead.

---

## Core Patterns

### Pattern 1: Basic Animated Skia Drawing

```tsx
import { useEffect } from "react";
import { Canvas, Circle, Group } from "@shopify/react-native-skia";
import {
  useSharedValue,
  useDerivedValue,
  withRepeat,
  withTiming,
} from "react-native-reanimated";

export const PulsingCircles = () => {
  const size = 256;
  const r = useSharedValue(0);
  const c = useDerivedValue(() => size - r.value);

  useEffect(() => {
    r.value = withRepeat(withTiming(size * 0.33, { duration: 1000 }), -1, true);
  }, []);

  return (
    <Canvas style={{ flex: 1 }}>
      <Group blendMode="multiply">
        <Circle cx={r} cy={r} r={r} color="cyan" />
        <Circle cx={c} cy={r} r={r} color="magenta" />
        <Circle cx={size / 2} cy={c} r={r} color="yellow" />
      </Group>
    </Canvas>
  );
};
```

### Pattern 2: Gesture-Driven Skia Animation

```tsx
import { View } from "react-native";
import { Canvas, Circle, Fill } from "@shopify/react-native-skia";
import { GestureDetector, Gesture } from "react-native-gesture-handler";
import { useSharedValue, withDecay } from "react-native-reanimated";

export const DraggableCircle = () => {
  const cx = useSharedValue(100);
  const cy = useSharedValue(100);

  const pan = Gesture.Pan()
    .onChange((e) => {
      cx.value += e.changeX;
      cy.value += e.changeY;
    })
    .onEnd((e) => {
      cx.value = withDecay({ velocity: e.velocityX });
      cy.value = withDecay({ velocity: e.velocityY });
    });

  return (
    <GestureDetector gesture={pan}>
      <Canvas style={{ flex: 1 }}>
        <Fill color="white" />
        <Circle cx={cx} cy={cy} r={30} color="dodgerblue" />
      </Canvas>
    </GestureDetector>
  );
};
```

### Pattern 3: Element-Level Gesture Tracking

When you need gestures on specific Skia elements (not the whole canvas):

```tsx
import { View } from "react-native";
import { Canvas, Circle, Fill } from "@shopify/react-native-skia";
import { GestureDetector, Gesture } from "react-native-gesture-handler";
import Animated, {
  useSharedValue,
  useAnimatedStyle,
} from "react-native-reanimated";

const radius = 30;

export const ElementTracking = () => {
  const x = useSharedValue(100);
  const y = useSharedValue(100);

  // Invisible animated overlay that matches the Skia element position
  const overlayStyle = useAnimatedStyle(() => ({
    position: "absolute",
    top: -radius,
    left: -radius,
    width: radius * 2,
    height: radius * 2,
    transform: [{ translateX: x.value }, { translateY: y.value }],
  }));

  const gesture = Gesture.Pan().onChange((e) => {
    x.value += e.changeX;
    y.value += e.changeY;
  });

  return (
    <View style={{ flex: 1 }}>
      <Canvas style={{ flex: 1 }}>
        <Fill color="white" />
        <Circle cx={x} cy={y} r={radius} color="cyan" />
      </Canvas>
      <GestureDetector gesture={gesture}>
        <Animated.View style={overlayStyle} />
      </GestureDetector>
    </View>
  );
};
```

### Pattern 4: Animated Gradient

```tsx
import {
  Canvas,
  LinearGradient,
  Fill,
  interpolateColors,
  vec,
} from "@shopify/react-native-skia";
import { useEffect } from "react";
import { useWindowDimensions } from "react-native";
import {
  useDerivedValue,
  useSharedValue,
  withRepeat,
  withTiming,
} from "react-native-reanimated";

const startColors = [
  "rgba(34, 193, 195, 0.4)",
  "rgba(34, 193, 195, 0.4)",
  "rgba(63, 94, 251, 1)",
  "rgba(253, 29, 29, 0.4)",
];
const endColors = [
  "rgba(0, 212, 255, 0.4)",
  "rgba(253, 187, 45, 0.4)",
  "rgba(252, 70, 107, 1)",
  "rgba(252, 176, 69, 0.4)",
];

export const AnimatedGradient = () => {
  const { width, height } = useWindowDimensions();
  const colorsIndex = useSharedValue(0);

  useEffect(() => {
    colorsIndex.value = withRepeat(
      withTiming(startColors.length - 1, { duration: 4000 }),
      -1,
      true
    );
  }, []);

  const gradientColors = useDerivedValue(() => [
    interpolateColors(colorsIndex.value, [0, 1, 2, 3], startColors),
    interpolateColors(colorsIndex.value, [0, 1, 2, 3], endColors),
  ]);

  return (
    <Canvas style={{ flex: 1 }}>
      <Fill>
        <LinearGradient
          start={vec(0, 0)}
          end={vec(width, height)}
          colors={gradientColors}
        />
      </Fill>
    </Canvas>
  );
};
```

> **Critical**: Use `interpolateColors` from `@shopify/react-native-skia`, NOT `interpolateColor` from `react-native-reanimated`. Skia uses a different internal color format.

### Pattern 5: Path Morphing Animation

```tsx
import { useEffect } from "react";
import { useSharedValue, withTiming } from "react-native-reanimated";
import { Skia, usePathInterpolation, Canvas, Path } from "@shopify/react-native-skia";

const path1 = Skia.Path.MakeFromSVGString(
  "M 16 25 C 32 27 43 28 49 28 C 54 28 62 28 73 26 C 66 54 60 70 55 74 C 51 77 40 75 27 55 Z"
)!;
const path2 = Skia.Path.MakeFromSVGString(
  "M 21 45 C 21 37 24 29 29 25 C 34 20 38 18 45 18 C 58 18 69 30 69 45 C 69 60 58 72 45 72 C 32 72 21 60 21 45 Z"
)!;

export const MorphingShape = () => {
  const progress = useSharedValue(0);

  useEffect(() => {
    progress.value = withTiming(1, { duration: 1000 });
  }, []);

  // Paths must have same number and types of commands for interpolation
  const path = usePathInterpolation(progress, [0, 1], [path1, path2]);

  return (
    <Canvas style={{ flex: 1 }}>
      <Path path={path} style="fill" color="purple" />
    </Canvas>
  );
};
```

### Pattern 6: Animated Clock (useClock + useDerivedValue)

```tsx
import { Canvas, Circle, vec, useClock } from "@shopify/react-native-skia";
import { useDerivedValue } from "react-native-reanimated";

export const LissajousCurve = () => {
  const t = useClock();

  const transform = useDerivedValue(() => {
    const scale = (2 / (3 - Math.cos(2 * t.value))) * 200;
    return [
      { translateX: scale * Math.cos(t.value) },
      { translateY: scale * (Math.sin(2 * t.value) / 2) },
    ];
  });

  return (
    <Canvas style={{ flex: 1 }}>
      <Circle c={vec(0, 0)} r={50} color="cyan" transform={transform} />
    </Canvas>
  );
};
```

### Pattern 7: Runtime Shaders (SKSL) with Animated Uniforms

```tsx
import { Canvas, Skia, Fill, Shader } from "@shopify/react-native-skia";
import { useEffect } from "react";
import { useWindowDimensions } from "react-native";
import { useSharedValue, useDerivedValue, withRepeat, withTiming } from "react-native-reanimated";

const source = Skia.RuntimeEffect.Make(`
  uniform float2 resolution;
  uniform float time;

  half4 main(float2 pos) {
    float2 uv = pos / resolution;
    float3 color = 0.5 + 0.5 * cos(time + uv.xyx + float3(0, 2, 4));
    return half4(color, 1.0);
  }
`)!;

export const AnimatedShader = () => {
  const { width, height } = useWindowDimensions();
  const time = useSharedValue(0);

  useEffect(() => {
    time.value = withRepeat(withTiming(Math.PI * 2, { duration: 4000 }), -1);
  }, []);

  const uniforms = useDerivedValue(() => ({
    resolution: [width, height],
    time: time.value,
  }));

  return (
    <Canvas style={{ flex: 1 }}>
      <Fill>
        <Shader source={source} uniforms={uniforms} />
      </Fill>
    </Canvas>
  );
};
```

### Pattern 8: Animated Transforms on Groups

```tsx
import { Canvas, Group, RoundedRect, Fill } from "@shopify/react-native-skia";
import { useDerivedValue, useSharedValue, withRepeat, withTiming } from "react-native-reanimated";
import { useEffect } from "react";

export const SpinningCard = () => {
  const rotation = useSharedValue(0);

  useEffect(() => {
    rotation.value = withRepeat(withTiming(Math.PI * 2, { duration: 2000 }), -1);
  }, []);

  const transform = useDerivedValue(() => [
    { rotate: rotation.value },
  ]);

  return (
    <Canvas style={{ flex: 1 }}>
      <Fill color="#1a1a2e" />
      <Group transform={transform} origin={{ x: 150, y: 300 }}>
        <RoundedRect x={100} y={250} width={100} height={100} r={12} color="#e94560" />
      </Group>
    </Canvas>
  );
};
```

---

## Skia Animation Hooks Reference

Skia provides these animation-specific hooks (from `@shopify/react-native-skia`):

| Hook | Purpose |
|------|---------|
| `usePathInterpolation(progress, input, paths)` | Morph between paths based on progress shared value |
| `useClock()` | Returns a continuously incrementing shared value (ms) |
| `useRectBuffer(count, callback)` | Create animated rectangle arrays (for Atlas API) |
| `useRSXformBuffer(count, callback)` | Create animated RSXform arrays (for Atlas API) |
| `useTextureValue(factory)` | Create Reanimated-compatible texture values |
| `useTextureValueFromPicture(picture, dims)` | Create texture from Skia Picture |
| `interpolateColors(value, input, colors)` | Color interpolation compatible with Skia's format |

---

## Reanimated v4 API Quick Reference (for Skia Usage)

### Core Hooks
```tsx
import {
  useSharedValue,      // Create shared values
  useDerivedValue,     // Compute derived values (runs on UI thread)
  useAnimatedReaction, // Side effects when values change
  useFrameCallback,    // Per-frame callbacks
} from "react-native-reanimated";
```

### Animation Functions
```tsx
import {
  withTiming,    // Duration-based
  withSpring,    // Spring physics
  withDecay,     // Momentum decay
  withRepeat,    // Loop/bounce
  withSequence,  // Sequential
  withDelay,     // Delayed start
  withClamp,     // Clamp values
  cancelAnimation,
} from "react-native-reanimated";
```

### Reanimated v4 Breaking Changes (from v3)
```tsx
// Worklet functions moved to react-native-worklets
// Old (deprecated, still works via re-export):
import { runOnUI, runOnJS } from "react-native-reanimated";

// New (recommended):
import { scheduleOnUI, scheduleOnRN } from "react-native-worklets";
// Note: argument passing syntax changed
// Old: runOnUI((greeting) => console.log(greeting))("Hello");
// New: scheduleOnUI((greeting) => console.log(greeting), "Hello");

// useAnimatedGestureHandler REMOVED — use Gesture Handler 2 API
// Gesture.Pan().onChange() / .onEnd() etc.
```

---

## Skia Declarative Components Reference

### Shapes
`Circle`, `Rect`, `RoundedRect`, `Path`, `Line`, `Oval`, `Points`, `Patch`, `Vertices`, `DiffRect`, `Box`, `BoxShadow`

### Text
`Text`, `TextPath`, `TextBlob`, `Glyphs`, `Paragraph`

### Images
`Image`, `ImageSVG`, `ImageShader`

### Shaders
`Shader`, `LinearGradient`, `RadialGradient`, `SweepGradient`, `TwoPointConicalGradient`, `Turbulence`, `FractalNoise`, `Color as ColorShader`, `Blend as BlendShader`

### Filters
`Blur`, `DisplacementMap`, `Offset`, `RuntimeShader` (image filter), `Shadow`, `DropShadow`, `Morphology`, `Blend` (image filter)

### Other
`Group`, `Paint`, `Fill`, `Canvas`, `Atlas`, `Picture`, `BackdropFilter`, `BackdropBlur`, `Mask`

---

## Common Pitfalls & Solutions

### 1. Color Interpolation
```tsx
// ❌ WRONG — Reanimated's interpolateColor uses different format
import { interpolateColor } from "react-native-reanimated";

// ✅ CORRECT — Use Skia's version
import { interpolateColors } from "@shopify/react-native-skia";
```

### 2. Shared Values as Props
```tsx
// ✅ Pass shared values directly to Skia components
<Circle cx={sharedX} r={sharedR} />

// ❌ Don't unwrap .value in render (breaks UI thread animation)
<Circle cx={sharedX.value} r={sharedR.value} />
```

### 3. Derived Values for Computed Props
```tsx
// ✅ Use useDerivedValue for computed transforms
const transform = useDerivedValue(() => [
  { rotate: rotation.value },
  { scale: scale.value },
]);
<Group transform={transform} origin={center}>

// ❌ Don't create arrays inline with .value access
<Group transform={[{ rotate: rotation.value }]}>
```

### 4. Gesture Handler Setup
Always wrap your app with `GestureHandlerRootView`:
```tsx
import { GestureHandlerRootView } from "react-native-gesture-handler";

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      {/* Your app */}
    </GestureHandlerRootView>
  );
}
```

### 5. Canvas Must Have Explicit Size
```tsx
// ✅ Canvas needs dimensions
<Canvas style={{ flex: 1 }}>
<Canvas style={{ width: 300, height: 300 }}>

// ❌ Canvas with no size won't render
<Canvas>
```

### 6. Reanimated v4 Requires New Architecture
Reanimated 4.x **only** supports New Architecture (Fabric). If on legacy architecture, stay on Reanimated 3.x.

### 7. useEffect for Starting Animations
```tsx
// ✅ Start animations in useEffect
useEffect(() => {
  progress.value = withRepeat(withTiming(1, { duration: 2000 }), -1, true);
}, []);

// ❌ Don't set shared values during render
progress.value = withTiming(1); // Called every render!
```

---

## Performance Tips

1. **Prefer `useDerivedValue` over `useAnimatedReaction`** for computing values — it's more efficient
2. **Batch related drawings in `Group`** components to reduce draw calls
3. **Use `Atlas`** for rendering many similar elements (sprites, particles) — far more efficient than individual components
4. **Avoid creating Skia objects in render** — memoize `Skia.Path.Make()`, `Skia.RuntimeEffect.Make()`, etc.
5. **Use `Picture`** component for complex static drawings that don't change
6. **Minimize `useDerivedValue` chains** — each adds overhead on the UI thread
7. **Profile with Flipper/React DevTools** — monitor UI thread FPS

---

## Testing Setup

```js
// jest.config.js
module.exports = {
  transformIgnorePatterns: [
    "node_modules/(?!(react-native|@react-native|@shopify/react-native-skia)/)",
  ],
  testEnvironment: "@shopify/react-native-skia/jestEnv.js",
  setupFilesAfterSetup: ["@shopify/react-native-skia/jestSetup.js"],
};
```

---

## Project Structure Recommendation

```
src/
├── components/
│   ├── canvas/           # Skia canvas components
│   │   ├── AnimatedBackground.tsx
│   │   ├── ParticleSystem.tsx
│   │   └── CustomChart.tsx
│   └── ui/               # Regular RN components
├── animations/
│   ├── hooks/            # Custom animation hooks
│   │   ├── useAnimatedPath.ts
│   │   └── useGestureAnimation.ts
│   └── shaders/          # SKSL shader files
│       ├── gradient.sksl
│       └── noise.sksl
├── utils/
│   └── skia.ts           # Skia helpers, path builders
└── App.tsx
```
