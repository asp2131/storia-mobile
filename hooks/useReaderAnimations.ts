import { useCallback } from 'react';
import { Dimensions } from 'react-native';
import { useAnimatedStyle, SharedValue } from 'react-native-reanimated';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

export function usePageAnimatedStyle(
  translateY: SharedValue<number>,
  activeIndexShared: SharedValue<number>
) {
  return useCallback((pageIndex: number) => {
    return useAnimatedStyle(() => {
      const idx = activeIndexShared.value;
      const diff = pageIndex - idx;

      if (diff === 0) {
        // Active page
        return {
          transform: [{ translateY: translateY.value }],
          opacity: 1,
          zIndex: 2,
        };
      } else if (diff === 1) {
        // Next page (below, slides up)
        const progress = Math.min(Math.max(-translateY.value / SCREEN_HEIGHT, 0), 1);
        return {
          transform: [
            { translateY: SCREEN_HEIGHT * (1 - progress) },
          ],
          opacity: 1,
          zIndex: 3,
        };
      } else if (diff === -1) {
        // Previous page (above, drifts up when swiping down)
        const progress = Math.min(Math.max(translateY.value / SCREEN_HEIGHT, 0), 1);
        return {
          transform: [
            { translateY: -SCREEN_HEIGHT * 0.2 * (1 - progress) },
          ],
          opacity: 0.4 + 0.6 * progress,
          zIndex: 1,
        };
      }

      // Off-screen
      return {
        transform: [{ translateY: diff > 0 ? SCREEN_HEIGHT : -SCREEN_HEIGHT }],
        opacity: 0,
        zIndex: 0,
      };
    });
  }, [translateY, activeIndexShared]);
}
