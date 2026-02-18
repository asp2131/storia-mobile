import { useEffect, useState, useRef, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  TouchableOpacity,
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
import { EdgeTapZones } from '@/components/reader/EdgeTapZones';
import { usePageAnimatedStyle } from '@/hooks/useReaderAnimations';
import { ReaderSkeleton } from '@/components/Skeleton';
import { GestureTutorial, hasSeenGestureTutorial, markGestureTutorialSeen } from '@/components/reader/GestureTutorial';
import type { PageData } from '@/types';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const SWIPE_THRESHOLD = SCREEN_HEIGHT * 0.18;
const VELOCITY_THRESHOLD = 500;

const SPRING_CONFIG = {
  damping: 22,
  stiffness: 200,
  mass: 1,
};

const UI_ANIMATION_DURATION = 250;

export default function ReaderScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const colors = useThemeColors();
  const bookId = id ?? '';

  // Data
  const { data: readerData, isLoading, error, refetch } = useReaderData(bookId);
  const { data: savedProgress } = useReadingProgress(bookId);

  // State
  const [activeIndex, setActiveIndex] = useState(0);
  const [showSettings, setShowSettings] = useState(false);
  const [isUIVisible, setIsUIVisible] = useState(true);
  const [showTutorial, setShowTutorial] = useState(false);
  const progressRestoredRef = useRef(false);
  const tutorialCheckedRef = useRef(false);

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

  // Tap to toggle UI visibility
  const tapGesture = Gesture.Tap()
    .maxDuration(250)
    .onEnd(() => {
      runOnJS(toggleUI)();
    });

  // Combine gestures - Race allows pan to win when swiping, tap to win on tap
  const composedGesture = Gesture.Race(panGesture, tapGesture);

  const toggleUI = useCallback(() => {
    setIsUIVisible((prev) => {
      const newValue = !prev;
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      return newValue;
    });
  }, []);

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
  // GESTURE TUTORIAL (FTUE)
  // ═══════════════════════════════════════════════════════════════

  useEffect(() => {
    if (tutorialCheckedRef.current || isLoading) return;
    
    const checkTutorial = async () => {
      const hasSeen = await hasSeenGestureTutorial();
      if (!hasSeen) {
        setShowTutorial(true);
      }
      tutorialCheckedRef.current = true;
    };
    
    checkTutorial();
  }, [isLoading]);

  const handleTutorialComplete = useCallback(() => {
    setShowTutorial(false);
    markGestureTutorialSeen();
  }, []);

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
  // EDGE TAP NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  const goToPreviousPage = useCallback(() => {
    if (activeIndex > 0) {
      const newIndex = activeIndex - 1;
      setActiveIndex(newIndex);
      activeIndexShared.value = newIndex;
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  }, [activeIndex, activeIndexShared]);

  const goToNextPage = useCallback(() => {
    if (activeIndex < totalPages - 1) {
      const newIndex = activeIndex + 1;
      setActiveIndex(newIndex);
      activeIndexShared.value = newIndex;
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  }, [activeIndex, totalPages, activeIndexShared]);

  // Animated styles for UI visibility
  const topBarAnimatedStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isUIVisible ? 1 : 0, { duration: UI_ANIMATION_DURATION }),
  }));

  const audioControlsAnimatedStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isUIVisible ? 1 : 0, { duration: UI_ANIMATION_DURATION }),
  }));

  const tapHintAnimatedStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isUIVisible ? 0 : 0.5, { duration: UI_ANIMATION_DURATION }),
  }));

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
    return <ReaderSkeleton />;
  }

  if (error || !readerData) {
    return (
      <View style={[styles.centered, { backgroundColor: colors.readerBg }]}>
        <Text style={[styles.errorTitle, { color: colors.error, fontFamily: fonts.sans }]}>
          Oops!
        </Text>
        <Text style={[styles.errorText, { color: colors.readerTextSecondary, fontFamily: fonts.sans }]}>
          {error?.message || 'Book not found'}
        </Text>
        <View style={styles.errorButtonsContainer}>
          <TouchableOpacity
            style={[styles.primaryButton, { backgroundColor: colors.readerProgressBarFill }]}
            onPress={() => refetch()}
            activeOpacity={0.8}
          >
            <Text style={[styles.primaryButtonText, { color: colors.readerBg, fontFamily: fonts.sans }]}>
              Try Again
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.secondaryButton, { borderColor: colors.readerTextSecondary }]}
            onPress={() => router.back()}
            activeOpacity={0.8}
          >
            <Text style={[styles.secondaryButtonText, { color: colors.readerTextSecondary, fontFamily: fonts.sans }]}>
              Go Back
            </Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.readerBg }]}>
      <GestureDetector gesture={composedGesture}>
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
      <Animated.View
        style={[styles.topBarContainer, topBarAnimatedStyle]}
        pointerEvents={isUIVisible ? 'auto' : 'none'}
      >
        <ReaderTopBar
          progressPercent={progressPercent}
          currentPage={currentPage}
          totalPages={totalPages}
          onClose={handleClose}
          onSettings={() => setShowSettings(true)}
        />
      </Animated.View>

      <Animated.View
        style={[styles.audioControlsContainer, audioControlsAnimatedStyle]}
        pointerEvents={isUIVisible ? 'auto' : 'none'}
      >
        <AudioControls
          hasNarration={!!narrationUrl}
          hasSoundscape={!!soundscapeUrl}
          isNarrationPlaying={isNarrationActive && narrationState.isPlaying}
          isSoundscapePlaying={isSoundscapeActive && soundscapeState.isPlaying}
          onToggleNarration={toggleNarration}
          onToggleSoundscape={toggleSoundscape}
        />
      </Animated.View>

      <SwipePageIndicator visible={isUIVisible && activeIndex === 0 && totalPages > 1} />

      {/* Edge Tap Zones - only visible when UI is hidden */}
      {!isUIVisible && (
        <EdgeTapZones
          onPrevious={goToPreviousPage}
          onNext={goToNextPage}
          isVisible={!isUIVisible}
        />
      )}

      {/* Tap hint when UI is hidden */}
      <Animated.View style={[styles.tapHintContainer, tapHintAnimatedStyle]} pointerEvents="none">
        <Text style={[styles.tapHintText, { color: colors.readerTextSecondary }]}>
          Tap to show controls
        </Text>
      </Animated.View>

      <GestureTutorial
        visible={showTutorial}
        onComplete={handleTutorialComplete}
      />
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
    gap: 12,
    paddingHorizontal: 32,
  },
  errorTitle: {
    fontSize: 24,
    fontWeight: '700',
  },
  errorText: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 22,
  },
  errorButtonsContainer: {
    marginTop: 24,
    gap: 12,
    width: '100%',
    maxWidth: 280,
  },
  primaryButton: {
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primaryButtonText: {
    fontSize: 16,
    fontWeight: '600',
  },
  secondaryButton: {
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 10,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  secondaryButtonText: {
    fontSize: 16,
    fontWeight: '500',
  },
  topBarContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 50,
  },
  audioControlsContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 120,
    zIndex: 40,
    pointerEvents: 'none',
  },
  tapHintContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 30,
  },
  tapHintText: {
    fontSize: 14,
    fontFamily: fonts.sans,
    fontWeight: '500',
    opacity: 0.7,
  },
});
