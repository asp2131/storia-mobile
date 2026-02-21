import { useEffect, useRef, useState, useCallback } from 'react';
import { AppState, type AppStateStatus } from 'react-native';
import { useNavigation } from 'expo-router';
import { useAudioPlayer, type AudioPlayerState } from './useAudioPlayer';
import type { PageData } from '@/types';

/**
 * Audio state tracking user's intent for playback
 * Separate from actual playback state to handle transitions properly
 */
type AudioState = {
  isNarrationActive: boolean;
  isSoundscapeActive: boolean;
  narrationUrl: string | null;
  soundscapeUrl: string | null;
  isTransitioning: boolean;
};

/**
 * Props for the useAudioManager hook
 */
export interface UseAudioManagerProps {
  pageData: PageData | undefined;
  bookId: string;
  pageNumber: number;
}

/**
 * Return type for the useAudioManager hook
 */
export interface UseAudioManagerReturn {
  // State
  isNarrationActive: boolean;
  isSoundscapeActive: boolean;
  narrationState: AudioPlayerState;
  soundscapeState: AudioPlayerState;
  isTransitioning: boolean;
  isDucked: boolean;
  soundscapeVolume: number;

  // Actions
  toggleNarration: () => Promise<void>;
  toggleSoundscape: () => Promise<void>;
  toggleBoth: (enabled: boolean) => Promise<void>;

  // Cleanup
  cleanup: () => Promise<void>;
}

/** Audio configuration constants */
const AUDIO_CONFIG = {
  SOUNDSCAPE: {
    NORMAL_VOLUME: 0.6,
    DUCKED_VOLUME: 0.15,
    FADE_IN_DURATION: 500,
    FADE_OUT_DURATION: 300,
  },
  NARRATION: {
    NORMAL_VOLUME: 1.0,
  },
} as const;

/**
 * Extract narration URL from page data
 * Checks both assignments array and legacy narrationUrl field
 */
function getNarrationUrl(pageData: PageData | undefined): string | null {
  if (!pageData) return null;

  const narrationAssignment = pageData.assignments?.find((a) => a.audioType === 'narration');
  return narrationAssignment?.audioUrl || pageData.narrationUrl || null;
}

/**
 * Extract soundscape URL from page data
 * Checks assignments array for soundscape type
 */
function getSoundscapeUrl(pageData: PageData | undefined): string | null {
  if (!pageData) return null;

  const soundscapeAssignment = pageData.assignments?.find((a) => a.audioType === 'soundscape');
  return soundscapeAssignment?.audioUrl || null;
}

/**
 * Custom hook for managing audio playback in the reader
 *
 * Handles:
 * - Page transitions with proper audio cleanup and loading
 * - Simultaneous narration and soundscape playback with ducking
 * - Audio state management and transitions
 * - Proper cleanup on unmount
 *
 * @example
 * ```tsx
 * const {
 *   isNarrationActive,
 *   isSoundscapeActive,
 *   toggleNarration,
 *   toggleSoundscape,
 *   cleanup
 * } = useAudioManager({ pageData, bookId, pageNumber });
 * ```
 */
export function useAudioManager({
  pageData,
  bookId,
  pageNumber,
}: UseAudioManagerProps): UseAudioManagerReturn {
  const navigation = useNavigation();

  const {
    narrationState,
    loadNarration,
    playNarration,
    pauseNarration,
    soundscapeState,
    loadSoundscape,
    playSoundscape,
    pauseSoundscape,
    setSoundscapeVolume,
    crossfadeSoundscape,
    cleanup: cleanupAudioPlayer,
  } = useAudioPlayer();

  // Track mount state to prevent state updates after unmount
  const isMountedRef = useRef(true);

  // Fade interval ref for volume ducking
  const fadeIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Ducking state management
  const [isDucked, setIsDucked] = useState(false);
  const [soundscapeVolume, setSoundscapeVolumeState] = useState<number>(AUDIO_CONFIG.SOUNDSCAPE.NORMAL_VOLUME);
  const intendedVolumeRef = useRef(AUDIO_CONFIG.SOUNDSCAPE.NORMAL_VOLUME);
  const duckingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Track previous page number to detect page changes
  const prevPageNumberRef = useRef<number>(pageNumber);

  // Track subscriptions and timers for cleanup
  const appStateSubscriptionRef = useRef<ReturnType<typeof AppState.addEventListener> | null>(null);
  const navigationUnsubscribeRef = useRef<(() => void) | null>(null);
  const transitionTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Audio state - tracks user's intent for playback
  const [audioState, setAudioState] = useState<AudioState>({
    isNarrationActive: false,
    isSoundscapeActive: false,
    narrationUrl: null,
    soundscapeUrl: null,
    isTransitioning: false,
  });

  /**
   * Safely update audio state only if component is still mounted
   */
  const safeSetAudioState = useCallback((updates: Partial<AudioState>) => {
    if (isMountedRef.current) {
      setAudioState((prev) => ({ ...prev, ...updates }));
    }
  }, []);

  /**
   * Fade soundscape volume to target level
   * Uses interval-based animation for smooth transitions
   */
  const fadeSoundscapeVolume = useCallback(async (targetVolume: number, duration: number) => {
    const steps = 20;
    const stepDuration = duration / steps;
    const currentVolume = soundscapeVolume;
    const volumeStep = (targetVolume - currentVolume) / steps;
    let currentStep = 0;

    if (fadeIntervalRef.current) {
      clearInterval(fadeIntervalRef.current);
      fadeIntervalRef.current = null;
    }

    return new Promise<void>((resolve) => {
      fadeIntervalRef.current = setInterval(() => {
        currentStep++;
        const newVolume = currentVolume + volumeStep * currentStep;
        const clampedVolume = Math.max(0, Math.min(1, newVolume));

        setSoundscapeVolume(clampedVolume).catch(() => {
          // Ignore errors during fade
        });

        if (isMountedRef.current) {
          setSoundscapeVolumeState(clampedVolume);
        }

        if (currentStep >= steps) {
          if (fadeIntervalRef.current) {
            clearInterval(fadeIntervalRef.current);
            fadeIntervalRef.current = null;
          }
          if (isMountedRef.current) {
            setSoundscapeVolumeState(targetVolume);
          }
          resolve();
        }
      }, stepDuration);
    });
  }, [soundscapeVolume, setSoundscapeVolume]);

  /**
   * Handle page transitions
   * This is the core logic that fixes the page transition bugs:
   * 1. Stops current narration immediately
   * 2. Loads new narration URL if available
   * 3. Auto-plays new narration if narration was active
   * 4. Crossfades soundscape if active
   * 5. Sets transitioning flag during the process
   */
  useEffect(() => {
    const handlePageTransition = async () => {
      if (!pageData) return;

      // Only run on actual page changes, not initial load
      const isPageChange = prevPageNumberRef.current !== pageNumber;
      prevPageNumberRef.current = pageNumber;

      const narrationUrl = getNarrationUrl(pageData);
      const soundscapeUrl = getSoundscapeUrl(pageData);

      safeSetAudioState({
        isTransitioning: true,
        narrationUrl,
        soundscapeUrl,
      });

      try {
        // Step 1: Stop current narration immediately
        if (narrationState.isPlaying) {
          await pauseNarration();
        }

        // Step 2: Load new narration if URL available
        if (narrationUrl) {
          await loadNarration(narrationUrl);

          // Step 3: Auto-play if narration was active and this is a page change
          // or if narration was already active (user expects continuous playback)
          if (audioState.isNarrationActive && isPageChange) {
            await playNarration();
          }
        }

        // Step 4: Handle soundscape transition
        if (soundscapeUrl && audioState.isSoundscapeActive) {
          // Crossfade to new soundscape
          await crossfadeSoundscape(soundscapeUrl);
        } else if (!soundscapeUrl && audioState.isSoundscapeActive) {
          // No soundscape for this page - pause current
          await pauseSoundscape();
        } else if (soundscapeUrl && !audioState.isSoundscapeActive && isPageChange) {
          // Load but don't play - user hasn't activated soundscape
          await loadSoundscape(soundscapeUrl);
        }
      } catch (error) {
        // Log error but don't crash
        if (__DEV__) {
          console.error('Audio transition error:', error);
        }
      } finally {
        safeSetAudioState({ isTransitioning: false });
      }
    };

    handlePageTransition();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pageNumber, pageData?.id, bookId]);

  /**
   * Smart ducking effect with delay to avoid "pumping" effect
   * When narration starts playing: fade soundscape to DUCKED_VOLUME
   * When narration stops: restore soundscape to NORMAL_VOLUME after brief delay
   */
  useEffect(() => {
    // Clear any pending ducking operations
    if (duckingTimeoutRef.current) {
      clearTimeout(duckingTimeoutRef.current);
      duckingTimeoutRef.current = null;
    }

    if (audioState.isNarrationActive && narrationState.isPlaying) {
      // Narration started - duck soundscape
      if (!isDucked && audioState.isSoundscapeActive && soundscapeState.isPlaying) {
        setIsDucked(true);
        fadeSoundscapeVolume(AUDIO_CONFIG.SOUNDSCAPE.DUCKED_VOLUME, AUDIO_CONFIG.SOUNDSCAPE.FADE_OUT_DURATION);
      }
    } else {
      // Narration stopped/paused - restore soundscape after brief delay
      if (isDucked) {
        duckingTimeoutRef.current = setTimeout(() => {
          if (isMountedRef.current) {
            setIsDucked(false);
            fadeSoundscapeVolume(AUDIO_CONFIG.SOUNDSCAPE.NORMAL_VOLUME, AUDIO_CONFIG.SOUNDSCAPE.FADE_IN_DURATION);
          }
        }, 500); // Small delay to avoid "pumping" effect
      }
    }

    return () => {
      if (duckingTimeoutRef.current) {
        clearTimeout(duckingTimeoutRef.current);
        duckingTimeoutRef.current = null;
      }
    };
  }, [
    narrationState.isPlaying,
    audioState.isNarrationActive,
    audioState.isSoundscapeActive,
    soundscapeState.isPlaying,
    isDucked,
    fadeSoundscapeVolume,
  ]);

  /**
   * Toggle narration playback
   * Handles edge cases like missing URLs and loading states
   */
  const toggleNarration = useCallback(async () => {
    const narrationUrl = getNarrationUrl(pageData);

    if (!narrationUrl) {
      // No narration available for this page
      return;
    }

    if (audioState.isNarrationActive) {
      // Stop narration
      await pauseNarration();
      safeSetAudioState({ isNarrationActive: false });
    } else {
      // Start narration
      if (!narrationState.isPlaying) {
        // Need to load first if not already loaded
        if (audioState.narrationUrl !== narrationUrl) {
          await loadNarration(narrationUrl);
        }
        await playNarration();
      }
      safeSetAudioState({ isNarrationActive: true });
    }
  }, [
    pageData,
    audioState.isNarrationActive,
    audioState.narrationUrl,
    narrationState.isPlaying,
    loadNarration,
    playNarration,
    pauseNarration,
    safeSetAudioState,
  ]);

  /**
   * Navigation cleanup - stop audio before leaving screen
   * Prevents audio from continuing when user navigates away
   */
  useEffect(() => {
    const unsubscribe = navigation.addListener('beforeRemove', () => {
      // Stop all audio before navigation
      pauseNarration();
      pauseSoundscape();

      // Clear any pending operations
      if (transitionTimeoutRef.current) {
        clearTimeout(transitionTimeoutRef.current);
        transitionTimeoutRef.current = null;
      }
      if (duckingTimeoutRef.current) {
        clearTimeout(duckingTimeoutRef.current);
        duckingTimeoutRef.current = null;
      }
    });

    navigationUnsubscribeRef.current = unsubscribe;

    return () => {
      unsubscribe();
      navigationUnsubscribeRef.current = null;
    };
  }, [navigation, pauseNarration, pauseSoundscape]);

  /**
   * App State handling (background/foreground)
   * Pauses audio when app goes to background
   */
  useEffect(() => {
    const subscription = AppState.addEventListener('change', (nextAppState: AppStateStatus) => {
      if (nextAppState === 'background') {
        // Pause audio when app goes to background
        pauseNarration();
        pauseSoundscape();
        if (isMountedRef.current) {
          safeSetAudioState({
            isNarrationActive: false,
            isSoundscapeActive: false,
          });
        }
      }
    });

    appStateSubscriptionRef.current = subscription;

    return () => {
      subscription.remove();
      appStateSubscriptionRef.current = null;
    };
  }, [pauseNarration, pauseSoundscape, safeSetAudioState]);

  /**
   * Toggle soundscape playback
   * Handles crossfading and volume restoration
   */
  const toggleSoundscape = useCallback(async () => {
    const soundscapeUrl = getSoundscapeUrl(pageData);

    if (!soundscapeUrl) {
      // No soundscape available for this page
      return;
    }

    if (audioState.isSoundscapeActive) {
      // Stop soundscape
      await pauseSoundscape();
      safeSetAudioState({ isSoundscapeActive: false });
    } else {
      // Start soundscape
      if (!soundscapeState.isPlaying) {
        // Need to load first if not already loaded
        if (audioState.soundscapeUrl !== soundscapeUrl) {
          await loadSoundscape(soundscapeUrl);
        }
        await playSoundscape();

        // Apply ducking if narration is also playing
        if (audioState.isNarrationActive && narrationState.isPlaying) {
          await setSoundscapeVolume(AUDIO_CONFIG.SOUNDSCAPE.DUCKED_VOLUME);
        } else {
          await setSoundscapeVolume(AUDIO_CONFIG.SOUNDSCAPE.NORMAL_VOLUME);
        }
      }
      safeSetAudioState({ isSoundscapeActive: true });
    }
  }, [
    pageData,
    audioState.isSoundscapeActive,
    audioState.soundscapeUrl,
    audioState.isNarrationActive,
    soundscapeState.isPlaying,
    narrationState.isPlaying,
    loadSoundscape,
    playSoundscape,
    pauseSoundscape,
    setSoundscapeVolume,
    safeSetAudioState,
  ]);

  /**
   * Toggle both narration and soundscape together
   * Useful for enabling/disabling all audio at once
   */
  const toggleBoth = useCallback(async (enabled: boolean) => {
    safeSetAudioState({ isTransitioning: true });

    const narrationUrl = getNarrationUrl(pageData);
    const soundscapeUrl = getSoundscapeUrl(pageData);

    try {
      if (enabled) {
        // Enable both
        if (narrationUrl && !audioState.isNarrationActive) {
          if (audioState.narrationUrl !== narrationUrl) {
            await loadNarration(narrationUrl);
          }
          await playNarration();
          safeSetAudioState({ isNarrationActive: true });
        }
        if (soundscapeUrl && !audioState.isSoundscapeActive) {
          if (audioState.soundscapeUrl !== soundscapeUrl) {
            await loadSoundscape(soundscapeUrl);
          }
          await playSoundscape();
          // Duck if narration is playing
          if (audioState.isNarrationActive && narrationState.isPlaying) {
            await setSoundscapeVolume(AUDIO_CONFIG.SOUNDSCAPE.DUCKED_VOLUME);
          }
          safeSetAudioState({ isSoundscapeActive: true });
        }
      } else {
        // Disable both
        if (audioState.isNarrationActive) {
          await pauseNarration();
          safeSetAudioState({ isNarrationActive: false });
        }
        if (audioState.isSoundscapeActive) {
          await pauseSoundscape();
          safeSetAudioState({ isSoundscapeActive: false });
        }
      }
    } finally {
      safeSetAudioState({ isTransitioning: false });
    }
  }, [
    pageData,
    audioState.isNarrationActive,
    audioState.isSoundscapeActive,
    audioState.narrationUrl,
    audioState.soundscapeUrl,
    narrationState.isPlaying,
    loadNarration,
    playNarration,
    pauseNarration,
    loadSoundscape,
    playSoundscape,
    pauseSoundscape,
    setSoundscapeVolume,
    safeSetAudioState,
  ]);

  /**
   * Comprehensive cleanup - bulletproof version
   * Stops all playback, clears all timers/subscriptions, and resets state
   */
  const cleanup = useCallback(async () => {
    // Stop all playback immediately
    await pauseNarration();
    await pauseSoundscape();

    // Clear all timers
    if (fadeIntervalRef.current) {
      clearInterval(fadeIntervalRef.current);
      fadeIntervalRef.current = null;
    }
    if (duckingTimeoutRef.current) {
      clearTimeout(duckingTimeoutRef.current);
      duckingTimeoutRef.current = null;
    }
    if (transitionTimeoutRef.current) {
      clearTimeout(transitionTimeoutRef.current);
      transitionTimeoutRef.current = null;
    }

    // Reset states only if still mounted
    if (isMountedRef.current) {
      safeSetAudioState({
        isNarrationActive: false,
        isSoundscapeActive: false,
        isTransitioning: false,
      });
      setIsDucked(false);
    }

    // Cleanup audio player
    await cleanupAudioPlayer();
  }, [pauseNarration, pauseSoundscape, cleanupAudioPlayer, safeSetAudioState]);

  /**
   * Component lifecycle management
   * Bulletproof cleanup on unmount - ensures audio NEVER continues after exit
   */
  useEffect(() => {
    isMountedRef.current = true;

    return () => {
      isMountedRef.current = false;

      // Immediately stop all audio - don't wait for async
      pauseNarration().catch(() => {
        // Ignore errors during cleanup
      });
      pauseSoundscape().catch(() => {
        // Ignore errors during cleanup
      });

      // Clear all pending operations immediately
      if (transitionTimeoutRef.current) {
        clearTimeout(transitionTimeoutRef.current);
        transitionTimeoutRef.current = null;
      }
      if (duckingTimeoutRef.current) {
        clearTimeout(duckingTimeoutRef.current);
        duckingTimeoutRef.current = null;
      }
      if (fadeIntervalRef.current) {
        clearInterval(fadeIntervalRef.current);
        fadeIntervalRef.current = null;
      }

      // Remove listeners
      if (navigationUnsubscribeRef.current) {
        navigationUnsubscribeRef.current();
        navigationUnsubscribeRef.current = null;
      }
      if (appStateSubscriptionRef.current) {
        appStateSubscriptionRef.current.remove();
        appStateSubscriptionRef.current = null;
      }

      // Final cleanup after brief delay to ensure stops complete
      setTimeout(() => {
        cleanupAudioPlayer().catch(() => {
          // Ignore errors during final cleanup
        });
      }, 100);
    };
  }, [pauseNarration, pauseSoundscape, cleanupAudioPlayer]);

  return {
    isNarrationActive: audioState.isNarrationActive,
    isSoundscapeActive: audioState.isSoundscapeActive,
    narrationState,
    soundscapeState,
    isTransitioning: audioState.isTransitioning,
    isDucked,
    soundscapeVolume,
    toggleNarration,
    toggleSoundscape,
    toggleBoth,
    cleanup,
  };
}
