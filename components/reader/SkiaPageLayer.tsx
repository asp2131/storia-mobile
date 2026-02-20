import { useState, useRef } from 'react';
import { Dimensions } from 'react-native';
import {
  useAnimatedStyle,
  useAnimatedReaction,
  runOnJS,
  type SharedValue,
} from 'react-native-reanimated';
import { PageRenderer } from '@/components/PageRenderer';
import type { PageData, WordTimestamp } from '@/types';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

interface SkiaPageLayerProps {
  page: PageData;
  pageIndex: number;
  /** React state — used for `isActive` flag on PageRenderer */
  activeIndex: number;
  /** Continuous scroll offset: 0 at page 0, -N*SCREEN_HEIGHT at page N */
  scrollOffset: SharedValue<number>;
  /** Mirrors activeIndex but lives on the UI thread for gesture continuity */
  activeIndexShared: SharedValue<number>;
  /**
   * Audio playback position synced to a SharedValue in the parent.
   * Allows word-index computation on the UI thread — React only re-renders
   * when the active word changes, not on every audio frame.
   */
  narrationPositionMs: SharedValue<number>;
  /** True when narration is toggled on AND currently playing */
  isNarrationPlaying: boolean;
}

/**
 * Replaces PageLayer with a self-contained, Fabric-native version.
 *
 * Key improvements over PageLayer:
 *
 * 1. **Owns its animated position** — `animatedStyle` is computed here from
 *    `scrollOffset` and `activeIndexShared` SharedValues directly, removing
 *    the `getPageAnimatedStyle` callback prop from the interface.
 *
 * 2. **Word-level narration bridge** — instead of re-rendering every audio
 *    frame, `useAnimatedReaction` computes the active word index on the UI
 *    thread and only calls `runOnJS` when the word actually changes.
 *    A 30 FPS audio tick becomes ~0.3 React renders per second on average.
 */
export function SkiaPageLayer({
  page,
  pageIndex,
  activeIndex,
  scrollOffset,
  activeIndexShared,
  narrationPositionMs,
  isNarrationPlaying,
}: SkiaPageLayerProps) {
  // `currentPositionMs` is only updated when the spoken word changes.
  const [currentPositionMs, setCurrentPositionMs] = useState(0);

  // Keep track of the last word index to gate runOnJS calls.
  const lastWordIndexRef = useRef(-1);

  const timestamps: WordTimestamp[] | null = page.narrationTimestamps ?? null;

  useAnimatedReaction(
    () => {
      // Worklet: compute active word index from current audio position.
      // Runs on the UI thread every frame while narration is playing.
      if (!timestamps || !isNarrationPlaying) return -1;

      const t = narrationPositionMs.value / 1000;
      let last = -1;

      for (let i = 0; i < timestamps.length; i++) {
        const w = timestamps[i];
        const n = timestamps[i + 1];

        if (t >= w.start && t <= w.end) return i;
        if (n && t > w.end && t < n.start) return i;
        if (!n && t >= w.start) return i;
        if (t > w.end) last = i;
      }

      return last;
    },
    (wordIndex, prevWordIndex) => {
      // Only cross the bridge when the word actually changes.
      if (wordIndex !== prevWordIndex && wordIndex !== lastWordIndexRef.current) {
        lastWordIndexRef.current = wordIndex;
        runOnJS(setCurrentPositionMs)(narrationPositionMs.value);
      }
    },
    [timestamps, isNarrationPlaying],
  );

  // Page position — inlined from usePageAnimatedStyle, runs entirely on UI thread.
  const animatedStyle = useAnimatedStyle(() => {
    const diff = pageIndex - activeIndexShared.value;
    const baseY = scrollOffset.value + pageIndex * SCREEN_HEIGHT;

    // Active page: tracks scrollOffset directly
    if (diff === 0) {
      return { transform: [{ translateY: baseY }], opacity: 1, zIndex: 2 };
    }

    // Next page: sits below, slides up as user swipes
    if (diff === 1) {
      return { transform: [{ translateY: baseY }], opacity: 1, zIndex: 3 };
    }

    // Previous page: parallax at 70% speed + fade
    if (diff === -1) {
      const parallaxY = baseY < 0 ? baseY * 0.7 : baseY;
      const progress = Math.min(Math.max(-baseY / SCREEN_HEIGHT, 0), 1);
      return {
        transform: [{ translateY: parallaxY }],
        opacity: 1 - progress * 0.75,
        zIndex: 1,
      };
    }

    // Off-screen: hidden
    return {
      transform: [{ translateY: diff > 0 ? SCREEN_HEIGHT : -SCREEN_HEIGHT }],
      opacity: 0,
      zIndex: 0,
    };
  });

  return (
    <PageRenderer
      page={page}
      activeWordIndex={-1}
      isActive={pageIndex === activeIndex}
      animatedStyle={animatedStyle}
      narrationTimestamps={timestamps}
      currentPositionMs={currentPositionMs}
      isNarrationPlaying={isNarrationPlaying}
    />
  );
}
