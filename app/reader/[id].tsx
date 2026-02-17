import { useEffect, useState, useRef, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  ActivityIndicator,
  StyleSheet,
  Dimensions,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withTiming,
  runOnJS,
} from 'react-native-reanimated';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { useReaderData } from '@/hooks/useBookData';
import { useReadingProgress, useAutoSaveProgress } from '@/hooks/useReadingProgress';
import { useReaderAudio } from '@/hooks/useReaderAudio';
import { useThemeColors, fonts } from '@/lib/theme';
import { ReaderTopBar } from '@/components/ReaderTopBar';
import { AudioControls } from '@/components/AudioControls';
import { PageRenderer } from '@/components/PageRenderer';
import { SwipePageIndicator } from '@/components/SwipePageIndicator';
import { PageLayer } from '@/components/reader/PageLayer';
import { usePageAnimatedStyle } from '@/hooks/useReaderAnimations';
import type { PageData } from '@/types';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');
const SWIPE_THRESHOLD = SCREEN_HEIGHT * 0.18;
const VELOCITY_THRESHOLD = 500;

const SPRING_CONFIG = {
  damping: 22,
  stiffness: 200,
  mass: 1,
};

export default function ReaderScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const colors = useThemeColors();
  const bookId = id ?? '';

  // Data
  const { data: readerData, isLoading, error } = useReaderData(bookId);
  const { data: savedProgress } = useReadingProgress(bookId);

  // State
  const [activeIndex, setActiveIndex] = useState(0);
  const [showSettings, setShowSettings] = useState(false);
  const progressRestoredRef = useRef(false);

  // Derived
  const pages = useMemo(
    () => [...(readerData?.pages ?? [])].sort((a, b) => a.pageNumber - b.pageNumber),
    [readerData?.pages]
  );
  const totalPages = pages.length;
  const currentPage = pages[activeIndex]?.pageNumber ?? 1;
  const pageData: PageData | undefined = pages[activeIndex];
  const progressPercent = totalPages > 0 ? ((activeIndex + 1) / totalPages) * 100 : 0;

  // Audio
  const {
    isNarrationActive,
    isSoundscapeActive,
    narrationState,
    soundscapeState,
    toggleNarration,
    toggleSoundscape,
    cleanup,
  } = useReaderAudio({ pageData, bookId });

  const narrationAssignment = pageData?.assignments?.find((a) => a.audioType === 'narration');
  const soundscapeAssignment = pageData?.assignments?.find((a) => a.audioType === 'soundscape');
  const narrationUrl = narrationAssignment?.audioUrl || pageData?.narrationUrl;
  const soundscapeUrl = soundscapeAssignment?.audioUrl;

  // ═══════════════════════════════════════════════════════════════
  // REANIMATED GESTURE PAGER
  // ═══════════════════════════════════════════════════════════════

  const translateY = useSharedValue(0);
  const activeIndexShared = useSharedValue(0);
  const getPageAnimatedStyle = usePageAnimatedStyle(translateY, activeIndexShared);

  const updateActiveIndex = useCallback(
    (newIndex: number) => {
      setActiveIndex(newIndex);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    },
    []
  );

  const panGesture = Gesture.Pan()
    .activeOffsetY([-15, 15])
    .onUpdate((e) => {
      // Clamp: don't allow overscroll past first/last page
      const idx = activeIndexShared.value;
      if (idx === 0 && e.translationY > 0) {
        // Rubber band at top
        translateY.value = e.translationY * 0.3;
      } else if (idx === totalPages - 1 && e.translationY < 0) {
        // Rubber band at bottom
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
        // Go to next page
        activeIndexShared.value = idx + 1;
        translateY.value = withSpring(0, SPRING_CONFIG);
        runOnJS(updateActiveIndex)(idx + 1);
      } else if (swipedDown && idx > 0) {
        // Go to previous page
        activeIndexShared.value = idx - 1;
        translateY.value = withSpring(0, SPRING_CONFIG);
        runOnJS(updateActiveIndex)(idx - 1);
      } else {
        // Snap back (dead zone)
        translateY.value = withSpring(0, SPRING_CONFIG);
      }
    });

  // ═══════════════════════════════════════════════════════════════
  // PROGRESS
  // ═══════════════════════════════════════════════════════════════

  useAutoSaveProgress({
    bookId,
    currentPage,
    totalPages,
    enabled: !isLoading && totalPages > 0,
  });

  // Restore reading progress
  useEffect(() => {
    if (progressRestoredRef.current || isLoading || !readerData) return;

    if (savedProgress?.currentPage && savedProgress.currentPage > 1 && savedProgress.currentPage <= totalPages) {
      const idx = pages.findIndex((p) => p.pageNumber === savedProgress.currentPage);
      if (idx > 0) {
        setActiveIndex(idx);
        activeIndexShared.value = idx;
      }
    }
    progressRestoredRef.current = true;
  }, [savedProgress, isLoading, readerData, totalPages, pages, activeIndexShared]);

  // ═══════════════════════════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════════════════════════

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      cleanup();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleClose = useCallback(() => {
    cleanup();
    router.back();
  }, [router, cleanup]);

  // ═══════════════════════════════════════════════════════════════
  // VISIBLE PAGES (virtualization window of ±1)
  // Optimized: O(1) slice instead of O(n) filter + indexOf
  // ═══════════════════════════════════════════════════════════════

  const visiblePages = useMemo(() => {
    const start = Math.max(0, activeIndex - 1);
    const end = Math.min(pages.length - 1, activeIndex + 1);
    const result: { page: typeof pages[0]; index: number }[] = [];
    for (let i = start; i <= end; i++) {
      result.push({ page: pages[i], index: i });
    }
    return result;
  }, [pages, activeIndex]);

  // ═══════════════════════════════════════════════════════════════
  // RENDER
  // ═══════════════════════════════════════════════════════════════

  if (isLoading) {
    return (
      <View style={[styles.centered, { backgroundColor: colors.readerBg }]}>
        <ActivityIndicator size="large" color={colors.readerProgressBarFill} />
        <Text style={[styles.loadingText, { color: colors.readerTextSecondary, fontFamily: fonts.sans }]}>
          Loading book...
        </Text>
      </View>
    );
  }

  if (error || !readerData) {
    return (
      <View style={[styles.centered, { backgroundColor: colors.readerBg }]}>
        <Text style={[styles.errorText, { color: colors.error, fontFamily: fonts.sans }]}>
          {error?.message || 'Book not found'}
        </Text>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.readerBg }]}>
      <GestureDetector gesture={panGesture}>
        <View style={styles.pagerContainer}>
          {visiblePages.map(({ page, index }) => (
            <PageLayer
              key={page.id}
              page={page}
              pageIndex={index}
              activeIndex={activeIndex}
              narrationTimestamps={page.narrationTimestamps ?? null}
              currentPositionMs={narrationState.positionMs}
              isNarrationPlaying={isNarrationActive && narrationState.isPlaying}
              usePageAnimatedStyle={getPageAnimatedStyle}
            />
          ))}
        </View>
      </GestureDetector>

      {/* Floating UI */}
      <ReaderTopBar
        progressPercent={progressPercent}
        currentPage={currentPage}
        totalPages={totalPages}
        onClose={handleClose}
        onSettings={() => setShowSettings(true)}
      />

      <AudioControls
        hasNarration={!!narrationUrl}
        hasSoundscape={!!soundscapeUrl}
        isNarrationPlaying={isNarrationActive && narrationState.isPlaying}
        isSoundscapePlaying={isSoundscapeActive && soundscapeState.isPlaying}
        onToggleNarration={toggleNarration}
        onToggleSoundscape={toggleSoundscape}
      />

      <SwipePageIndicator visible={activeIndex === 0 && totalPages > 1} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  pagerContainer: {
    flex: 1,
  },
  centered: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 16,
  },
  loadingText: {
    fontSize: 15,
  },
  errorText: {
    fontSize: 16,
    textAlign: 'center',
    paddingHorizontal: 32,
  },
});
