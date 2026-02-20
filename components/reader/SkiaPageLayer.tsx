import { useState, useRef } from 'react';
import { Dimensions } from 'react-native';
import {
  useAnimatedStyle,
  useAnimatedReaction,
  runOnJS,
  interpolate,
  interpolateColor,
  Extrapolation,
  Easing,
  type SharedValue,
} from 'react-native-reanimated';
import { PageRenderer } from '@/components/PageRenderer';
import type { PageData, WordTimestamp } from '@/types';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

// 3D Card Stack Animation Constants - Tuned for smooth, premium feel
const SCALE_MIN = 0.92;
const SCALE_MAX = 1.0;
const ROTATION_MAX_DEG = 12; // Reduced from 15° for smoother feel
const SHADOW_OPACITY_MAX = 0.35;
const SHADOW_OPACITY_MIN = 0.08;
const PERSPECTIVE = 1200; // Higher = less dramatic 3D effect

// Custom ease-out function for smooth transitions (worklet-safe)
function easeOutCubic(t: number): number {
  'worklet';
  return 1 - Math.pow(1 - t, 3);
}

interface SkiaPageLayerProps {
  page: PageData;
  pageIndex: number;
  /** React state — used for `isActive` flag on PageRenderer */
  activeIndex: number;
  /** Continuous scroll offset: 0 at page 0, -N*SCREEN_HEIGHT at page N */
  scrollOffset: SharedValue<number>;
  /** Mirrors activeIndex but lives on the UI thread for gesture continuity */
  activeIndexShared: SharedValue<number>;
  /** Total number of pages for edge case handling */
  totalPages: number;
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
 *
 * 3. **3D Card Stack animations** — smooth scale, rotation, and shadow transitions
 *    with optimized worklet calculations for 60fps performance.
 */
export function SkiaPageLayer({
  page,
  pageIndex,
  activeIndex,
  scrollOffset,
  activeIndexShared,
  totalPages,
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

  // Page position with 3D card stack animations — runs entirely on UI thread.
  const animatedStyle = useAnimatedStyle(() => {
    'worklet';
    
    const diff = pageIndex - activeIndexShared.value;
    const baseY = scrollOffset.value + pageIndex * SCREEN_HEIGHT;
    const isFirstPage = pageIndex === 0;
    const isLastPage = pageIndex === totalPages - 1;
    
    // Normalize progress to 0-1 range for smooth interpolation
    // progress = 0 when page is centered (active)
    // progress = 1 when page is fully off-screen
    const rawProgress = Math.abs(baseY) / SCREEN_HEIGHT;
    const progress = Math.min(rawProgress, 1);
    
    // Apply easing curve for smoother, more natural transitions
    const easedProgress = easeOutCubic(progress);
    
    // Calculate scale with smooth interpolation
    const scale = interpolate(
      easedProgress,
      [0, 1],
      [SCALE_MAX, SCALE_MIN],
      Extrapolation.CLAMP
    );
    
    // Calculate rotation based on position relative to active page
    // Pages above center (diff < 0) rotate away from viewer
    // Pages below center (diff > 0) rotate toward viewer
    // Edge case: First page doesn't rotate below (nothing there)
    // Edge case: Last page doesn't rotate above (nothing there)
    let rotateX = 0;
    
    if (diff === 0) {
      // Active page: subtle rotation when swiping
      // Only rotate if not first page and swiping up, or not last page and swiping down
      if (baseY < 0 && !isLastPage) {
        // Swiping up (moving to next page)
        rotateX = interpolate(
          easedProgress,
          [0, 1],
          [0, ROTATION_MAX_DEG],
          Extrapolation.CLAMP
        );
      } else if (baseY > 0 && !isFirstPage) {
        // Swiping down (moving to prev page)
        rotateX = interpolate(
          easedProgress,
          [0, 1],
          [0, -ROTATION_MAX_DEG],
          Extrapolation.CLAMP
        );
      }
    } else if (diff === 1) {
      // Next page: rotates toward viewer as it comes to front
      rotateX = interpolate(
        easedProgress,
        [0, 1],
        [-ROTATION_MAX_DEG * 0.5, 0],
        Extrapolation.CLAMP
      );
    } else if (diff === -1) {
      // Previous page: rotates away from viewer
      // Last page has reduced rotation (nothing below to show)
      const maxRotation = isLastPage ? ROTATION_MAX_DEG * 0.3 : ROTATION_MAX_DEG;
      rotateX = interpolate(
        easedProgress,
        [0, 1],
        [0, -maxRotation],
        Extrapolation.CLAMP
      );
    }
    
    // Calculate shadow values for depth perception
    const shadowOpacity = interpolate(
      easedProgress,
      [0, 0.5, 1],
      [SHADOW_OPACITY_MIN, SHADOW_OPACITY_MAX, SHADOW_OPACITY_MAX * 0.8],
      Extrapolation.CLAMP
    );
    
    const shadowRadius = interpolate(
      easedProgress,
      [0, 1],
      [8, 20],
      Extrapolation.CLAMP
    );
    
    const shadowOffsetY = interpolate(
      easedProgress,
      [0, 1],
      [2, 10],
      Extrapolation.CLAMP
    );
    
    const elevation = interpolate(
      easedProgress,
      [0, 1],
      [2, 8],
      Extrapolation.CLAMP
    );
    
    // Background color shifts slightly for depth
    const backgroundColor = interpolateColor(
      easedProgress,
      [0, 1],
      ['#ffffff', '#f0f0f0']
    );
    
    // Opacity fades for non-active pages
    const opacity = diff === 0 ? 1 : interpolate(
      easedProgress,
      [0, 1],
      [0.95, 0.7],
      Extrapolation.CLAMP
    );
    
    // Z-index based on distance from active page
    // Active page is always on top (zIndex 10)
    const zIndex = 10 - Math.abs(diff);
    
    // Build transform array with proper order for 3D effect
    // Order: perspective -> translateY -> scale -> rotateX
    const transforms: any[] = [
      { perspective: PERSPECTIVE },
      { translateY: baseY },
      { scale },
    ];
    
    // Only add rotation if there's actual rotation
    if (rotateX !== 0) {
      transforms.push({ rotateX: `${rotateX}deg` });
    }
    
    return {
      transform: transforms,
      opacity,
      zIndex,
      shadowColor: '#000000',
      shadowOpacity,
      shadowRadius,
      shadowOffset: {
        width: 0,
        height: shadowOffsetY,
      },
      elevation,
      backgroundColor,
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
