import React, { useCallback, useMemo } from 'react';
import { View, Dimensions } from 'react-native';
import { useSharedValue, withSpring, runOnJS } from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { useReader } from '@/contexts/ReaderContext';
import { usePageAnimatedStyle } from '@/hooks/useReaderAnimations';
import { PageLayer } from './PageLayer';
import type { PageData } from '@/types';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const SWIPE_THRESHOLD = SCREEN_HEIGHT * 0.18;
const VELOCITY_THRESHOLD = 500;

const SPRING_CONFIG = {
  damping: 22,
  stiffness: 200,
  mass: 1,
};

export function ReaderContainer() {
  const { pages, activeIndex, goToPage } = useReader();

  const translateY = useSharedValue(0);
  const activeIndexShared = useSharedValue(activeIndex);

  const getPageAnimatedStyle = usePageAnimatedStyle(translateY, activeIndexShared);

  const totalPages = pages.length;

  const updateIndex = useCallback(
    (newIndex: number) => {
      goToPage(newIndex);
    },
    [goToPage]
  );

  const panGesture = Gesture.Pan()
    .activeOffsetY([-15, 15])
    .onUpdate((e) => {
      const idx = activeIndexShared.value;
      if (idx === 0 && e.translationY > 0) {
        translateY.value = e.translationY * 0.3;
      } else if (idx === totalPages - 1 && e.translationY < 0) {
        translateY.value = e.translationY * 0.3;
      } else {
        translateY.value = e.translationY;
      }
    })
    .onEnd((e) => {
      const idx = activeIndexShared.value;
      const swipedUp = e.translationY < -SWIPE_THRESHOLD || e.velocityY < -VELOCITY_THRESHOLD;
      const swipedDown = e.translationY > SWIPE_THRESHOLD || e.velocityY > VELOCITY_THRESHOLD;

      if (swipedUp && idx < totalPages - 1) {
        activeIndexShared.value = idx + 1;
        translateY.value = withSpring(0, SPRING_CONFIG);
        runOnJS(updateIndex)(idx + 1);
      } else if (swipedDown && idx > 0) {
        activeIndexShared.value = idx - 1;
        translateY.value = withSpring(0, SPRING_CONFIG);
        runOnJS(updateIndex)(idx - 1);
      } else {
        translateY.value = withSpring(0, SPRING_CONFIG);
      }
    });

  const visiblePages = useMemo(() => {
    return pages.filter((_: PageData, i: number) => Math.abs(i - activeIndex) <= 1);
  }, [pages, activeIndex]);

  React.useEffect(() => {
    activeIndexShared.value = activeIndex;
  }, [activeIndex, activeIndexShared]);

  return (
    <GestureDetector gesture={panGesture}>
      <View style={{ flex: 1 }}>
        {visiblePages.map((page: PageData) => {
          const pageIndex = pages.indexOf(page);
          return (
            <PageLayer
              key={page.id}
              page={page}
              pageIndex={pageIndex}
              activeIndex={activeIndex}
              narrationTimestamps={page.narrationTimestamps ?? null}
              currentPositionMs={0}
              isNarrationPlaying={false}
              usePageAnimatedStyle={getPageAnimatedStyle}
            />
          );
        })}
      </View>
    </GestureDetector>
  );
}
