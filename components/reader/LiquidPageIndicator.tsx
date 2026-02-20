import {
  Canvas,
  Group,
  Circle,
  Paint,
  Blur,
  ColorMatrix,
} from '@shopify/react-native-skia';
import Animated, {
  useAnimatedStyle,
  useDerivedValue,
  withTiming,
  type SharedValue,
} from 'react-native-reanimated';
import { StyleSheet, Dimensions } from 'react-native';

const SCREEN_HEIGHT = Dimensions.get('window').height;

const DOT_SPACING = 18;
const DOT_PADDING = 20;
const CANVAS_WIDTH = 28;
const UI_DURATION = 300;

/**
 * Gooey metaball color matrix.
 *
 * The Blur filter blurs both dots. The ColorMatrix then cranks the alpha
 * channel contrast: values near 1 are pushed to full-opaque, values near 0
 * are pushed to fully transparent. Where two blurred dots overlap, the
 * blended alpha crosses the threshold and "snaps" them together — creating
 * the liquid-metal merge effect.
 */
const GOOEY_MATRIX: number[] = [
  1, 0, 0, 0, 0,
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 18, -7,
];

interface LiquidPageIndicatorProps {
  totalPages: number;
  scrollOffset: SharedValue<number>;
  isVisible: boolean;
}

/**
 * Replaces the discrete View-based PageDots with a single Skia Canvas.
 *
 * The active dot's Y coordinate is a `useDerivedValue` computed directly
 * from `scrollOffset` on the UI thread — zero React renders during a swipe.
 * The blur + ColorMatrix combo fuses the active dot and its nearest
 * neighbour during transit, creating a fluid liquid-metal bead effect.
 */
export function LiquidPageIndicator({
  totalPages,
  scrollOffset,
  isVisible,
}: LiquidPageIndicatorProps) {
  const canvasHeight = totalPages * DOT_SPACING + DOT_PADDING * 2;

  // Slide in/out from the right edge + fade
  const containerStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isVisible ? 1 : 0, { duration: UI_DURATION }),
    transform: [
      { translateX: withTiming(isVisible ? 0 : 10, { duration: UI_DURATION }) },
    ],
  }));

  // Active dot Y — fully driven from scrollOffset on the UI thread.
  // No React state, no bridge round-trip during swipes.
  const activeY = useDerivedValue(() => {
    const exactIndex = -scrollOffset.value / SCREEN_HEIGHT;
    const clamped = Math.min(Math.max(exactIndex, 0), totalPages - 1);
    return DOT_PADDING + clamped * DOT_SPACING;
  });

  if (totalPages <= 1) return null;

  return (
    <Animated.View
      style={[
        styles.container,
        // Exact vertical centering: top:'50%' + marginTop = -height/2
        { marginTop: -(canvasHeight / 2) },
        containerStyle,
      ]}
      pointerEvents="none"
    >
      <Canvas style={{ width: CANVAS_WIDTH, height: canvasHeight }}>
        {/*
          Group layer applies Blur then ColorMatrix to the composited
          result of all children — this is what produces the gooey merge.
        */}
        <Group
          layer={
            <Paint>
              <Blur blur={4} />
              <ColorMatrix matrix={GOOEY_MATRIX} />
            </Paint>
          }
        >
          {/* Static background dots */}
          {Array.from({ length: totalPages }, (_, i) => (
            <Circle
              key={i}
              cx={CANVAS_WIDTH / 2}
              cy={DOT_PADDING + i * DOT_SPACING}
              r={3}
              color="rgba(255,255,255,0.4)"
            />
          ))}

          {/* Liquid active dot — interpolates continuously between pages */}
          <Circle
            cx={CANVAS_WIDTH / 2}
            cy={activeY}
            r={5.5}
            color="rgba(255,255,255,0.95)"
          />
        </Group>
      </Canvas>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    right: 8,
    top: '50%',
    zIndex: 35,
  },
});
