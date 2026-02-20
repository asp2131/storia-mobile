import { useCallback } from 'react';
import { Dimensions } from 'react-native';
import { useAnimatedStyle, SharedValue } from 'react-native-reanimated';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

/**
 * Continuous scrollOffset architecture:
 *
 * scrollOffset is a single SharedValue representing the total vertical scroll position.
 * At rest on page N, scrollOffset = -N * SCREEN_HEIGHT.
 *
 * Each page's position is derived from:
 *   pageTranslateY = scrollOffset + pageIndex * SCREEN_HEIGHT
 *
 * All easing, momentum (withDecay), and snap behaviour live in the gesture
 * handler that drives scrollOffset — the styles here are pure position math.
 */
export function usePageAnimatedStyle(
  scrollOffset: SharedValue<number>,
  activeIndexShared: SharedValue<number>
): (pageIndex: number) => ReturnType<typeof useAnimatedStyle> {
  return useCallback(
    (pageIndex: number) => {
      return useAnimatedStyle(() => {
        const activeIndex = activeIndexShared.value;
        const diff = pageIndex - activeIndex;

        // Base position derived from continuous scroll offset
        const baseY = scrollOffset.value + pageIndex * SCREEN_HEIGHT;

        // ── Active page (diff === 0) ──────────────────────────────
        // Tracks scrollOffset directly — no extra transform needed.
        if (diff === 0) {
          return {
            transform: [{ translateY: baseY }],
            opacity: 1,
            zIndex: 2,
          };
        }

        // ── Next page (diff === 1) ────────────────────────────────
        // Sits at SCREEN_HEIGHT below when at rest, slides up as
        // scrollOffset decreases. No per-style easing — smoothness
        // comes from the scrollOffset animation itself.
        if (diff === 1) {
          return {
            transform: [{ translateY: baseY }],
            opacity: 1,
            zIndex: 3,
          };
        }

        // ── Previous page (diff === -1) ───────────────────────────
        // Parallax: moves at 70% speed when above viewport, creating
        // a sense of depth — the previous page lags behind slightly.
        // Opacity fades to 0.25 as it moves fully above.
        if (diff === -1) {
          const parallaxY = baseY < 0 ? baseY * 0.7 : baseY;

          // progress: 0 when page is at rest (baseY = 0), 1 when fully above
          const progress = Math.min(Math.max(-baseY / SCREEN_HEIGHT, 0), 1);
          const opacity = 1 - progress * 0.75; // fades from 1.0 → 0.25

          return {
            transform: [{ translateY: parallaxY }],
            opacity,
            zIndex: 1,
          };
        }

        // ── Off-screen pages (|diff| > 1) ─────────────────────────
        // Hidden and positioned out of view to avoid unnecessary rendering.
        return {
          transform: [{ translateY: diff > 0 ? SCREEN_HEIGHT : -SCREEN_HEIGHT }],
          opacity: 0,
          zIndex: 0,
        };
      });
    },
    [scrollOffset, activeIndexShared]
  );
}
