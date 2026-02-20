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
  withTiming,
  runOnJS,
  Easing,
} from 'react-native-reanimated';
import { scheduleOnRN } from 'react-native-worklets';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { useReaderData } from '@/hooks/useBookData';
import { useReadingProgress, useAutoSaveProgress } from '@/hooks/useReadingProgress';
import { useReaderAudio } from '@/hooks/useReaderAudio';
import { useThemeColors, fonts } from '@/lib/theme';
import { ReaderTopBar } from '@/components/ReaderTopBar';
import { AudioControls } from '@/components/AudioControls';
import { SwipePageIndicator } from '@/components/SwipePageIndicator';
import { SkiaPageLayer } from '@/components/reader/SkiaPageLayer';
import { LiquidPageIndicator } from '@/components/reader/LiquidPageIndicator';
import { EdgeTapZones } from '@/components/reader/EdgeTapZones';
import { ReaderSkeleton } from '@/components/Skeleton';
import { GestureTutorial, hasSeenGestureTutorial, markGestureTutorialSeen } from '@/components/reader/GestureTutorial';
import type { PageData } from '@/types';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const SWIPE_THRESHOLD = SCREEN_HEIGHT * 0.18;
const VELOCITY_THRESHOLD = 500;

// easeOutExpo bezier — starts fast, decelerates very smoothly (Lenis feel)
const EASE_OUT_EXPO = Easing.bezier(0.16, 1, 0.3, 1);

// easeOutQuart for snap-back (cancelled swipe) — slightly less dramatic
const EASE_OUT_QUART = Easing.bezier(0.25, 1, 0.5, 1);

const UI_ANIMATION_DURATION = 300;

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

  // ===============================================================
  // NARRATION POSITION — SharedValue bridge
  // Sync positionMs from the JS audio hook into a SharedValue so
  // SkiaPageLayer can compute word indices on the UI thread.
  // ===============================================================

  const narrationPositionShared = useSharedValue(0);

  useEffect(() => {
    narrationPositionShared.value = narrationState.positionMs;
  }, [narrationState.positionMs, narrationPositionShared]);

  // ===============================================================
  // REANIMATED GESTURE PAGER
  // ===============================================================

  const scrollOffset = useSharedValue(0); // continuous, -pageIndex * SCREEN_HEIGHT at rest
  const activeIndexShared = useSharedValue(0);
  const baseScrollOffset = useSharedValue(0); // captures position at gesture start

  // scheduleOnRN replaces runOnJS — the Reanimated v4 / worklets API
  const updateActiveIndex = useCallback(
    (newIndex: number) => {
      setActiveIndex(newIndex);
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    },
    []
  );

  const toggleUI = useCallback(() => {
    setIsUIVisible((prev) => {
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      return !prev;
    });
  }, []);

  const panGesture = Gesture.Pan()
    .activeOffsetY([-12, 12])
    .onBegin(() => {
      baseScrollOffset.value = scrollOffset.value;
    })
    .onUpdate((e) => {
      const rawOffset = baseScrollOffset.value + e.translationY;
      const minOffset = -(totalPages - 1) * SCREEN_HEIGHT;
      const maxOffset = 0;

      if (rawOffset > maxOffset) {
        scrollOffset.value = maxOffset + (rawOffset - maxOffset) * 0.15;
      } else if (rawOffset < minOffset) {
        scrollOffset.value = minOffset + (rawOffset - minOffset) * 0.15;
      } else {
        scrollOffset.value = rawOffset;
      }
    })
    .onEnd((e) => {
      const idx = activeIndexShared.value;
      const totalPgs = totalPages;

      const swipedUp = e.translationY < -SWIPE_THRESHOLD || e.velocityY < -VELOCITY_THRESHOLD;
      const swipedDown = e.translationY > SWIPE_THRESHOLD || e.velocityY > VELOCITY_THRESHOLD;

      let destIndex = idx;
      if (swipedUp && idx < totalPgs - 1) {
        destIndex = idx + 1;
      } else if (swipedDown && idx > 0) {
        destIndex = idx - 1;
      }

      const destOffset = -destIndex * SCREEN_HEIGHT;

      const distance = Math.abs(destOffset - scrollOffset.value);
      const speed = Math.max(Math.abs(e.velocityY), 100);
      const duration = Math.min(Math.max((distance / speed) * 1000 * 0.6, 280), 520);

      if (destIndex !== idx) {
        activeIndexShared.value = destIndex;
        // v4 worklets API: scheduleOnRN(fn, ...args) replaces runOnJS(fn)(args)
        scheduleOnRN(updateActiveIndex, destIndex);
      }

      scrollOffset.value = withTiming(destOffset, {
        duration,
        easing: destIndex !== idx ? EASE_OUT_EXPO : EASE_OUT_QUART,
      });
    });

  const tapGesture = Gesture.Tap()
    .maxDuration(250)
    .onEnd(() => {
      scheduleOnRN(toggleUI);
    });

  const composedGesture = Gesture.Race(panGesture, tapGesture);

  // ===============================================================
  // PROGRESS
  // ===============================================================

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
        scrollOffset.value = -idx * SCREEN_HEIGHT;
      }
    }
    progressRestoredRef.current = true;
  }, [savedProgress, isLoading, readerData, totalPages, pages, activeIndexShared, scrollOffset]);

  // ===============================================================
  // GESTURE TUTORIAL (FTUE)
  // ===============================================================

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

  // ===============================================================
  // CLEANUP
  // ===============================================================

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

  // ===============================================================
  // EDGE TAP NAVIGATION
  // ===============================================================

  const goToPreviousPage = useCallback(() => {
    if (activeIndex > 0) {
      const newIndex = activeIndex - 1;
      setActiveIndex(newIndex);
      activeIndexShared.value = newIndex;
      scrollOffset.value = withTiming(-newIndex * SCREEN_HEIGHT, {
        duration: 400,
        easing: EASE_OUT_EXPO,
      });
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  }, [activeIndex, activeIndexShared, scrollOffset]);

  const goToNextPage = useCallback(() => {
    if (activeIndex < totalPages - 1) {
      const newIndex = activeIndex + 1;
      setActiveIndex(newIndex);
      activeIndexShared.value = newIndex;
      scrollOffset.value = withTiming(-newIndex * SCREEN_HEIGHT, {
        duration: 400,
        easing: EASE_OUT_EXPO,
      });
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  }, [activeIndex, totalPages, activeIndexShared, scrollOffset]);

  // ===============================================================
  // UI VISIBILITY — Reanimated v4 CSS-style transitions
  // These replace the useAnimatedStyle + withTiming pattern for
  // state-driven show/hide. Fabric animates the style diff natively.
  // ===============================================================

  const topBarAnimatedStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isUIVisible ? 1 : 0, { duration: UI_ANIMATION_DURATION }),
  }));

  const audioControlsAnimatedStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isUIVisible ? 1 : 0, { duration: UI_ANIMATION_DURATION }),
  }));

  const tapHintAnimatedStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isUIVisible ? 0 : 0.4, { duration: UI_ANIMATION_DURATION }),
  }));

  // ===============================================================
  // VISIBLE PAGES (virtualization window of +/-1)
  // ===============================================================

  const visiblePages = useMemo(() => {
    const start = Math.max(0, activeIndex - 1);
    const end = Math.min(pages.length - 1, activeIndex + 1);
    const result: { page: typeof pages[0]; index: number }[] = [];
    for (let i = start; i <= end; i++) {
      result.push({ page: pages[i], index: i });
    }
    return result;
  }, [pages, activeIndex]);

  const isNarrationPlaying = isNarrationActive && narrationState.isPlaying;

  // ===============================================================
  // RENDER
  // ===============================================================

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
            <SkiaPageLayer
              key={page.id}
              page={page}
              pageIndex={index}
              activeIndex={activeIndex}
              scrollOffset={scrollOffset}
              activeIndexShared={activeIndexShared}
              narrationPositionMs={narrationPositionShared}
              isNarrationPlaying={isNarrationPlaying}
            />
          ))}
        </View>
      </GestureDetector>

      {/* Liquid Skia pagination — right edge, driven from scrollOffset SharedValue */}
      <LiquidPageIndicator
        totalPages={totalPages}
        scrollOffset={scrollOffset}
        isVisible={isUIVisible}
      />

      {/* Floating UI - Top bar */}
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

      {/* Floating UI - Audio controls */}
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
        <View style={styles.tapHintPill}>
          <Text style={styles.tapHintText}>
            Tap to show controls
          </Text>
        </View>
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
    bottom: 48,
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 30,
  },
  tapHintPill: {
    backgroundColor: 'rgba(0,0,0,0.4)',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  tapHintText: {
    fontSize: 12,
    fontFamily: fonts.sans,
    fontWeight: '500',
    color: 'rgba(255,255,255,0.5)',
    letterSpacing: 0.3,
  },
});
