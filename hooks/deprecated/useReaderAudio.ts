import { useEffect, useRef, useState, useCallback } from 'react';
import { useAudioPlayer, type AudioPlayerState } from '../useAudioPlayer';
import { useLocalPreferences } from '../useLocalPreferences';
import type { PageData } from '@/types';

type UseReaderAudioProps = {
  pageData: PageData | undefined;
  bookId: string;
};

type UseReaderAudioReturn = {
  isNarrationActive: boolean;
  isSoundscapeActive: boolean;
  narrationState: AudioPlayerState;
  soundscapeState: AudioPlayerState;
  toggleNarration: () => Promise<void>;
  toggleSoundscape: () => Promise<void>;
  loadNarration: (url: string) => Promise<void>;
  loadSoundscape: (url: string) => Promise<void>;
  cleanup: () => void;
};

export function useReaderAudio({ pageData }: UseReaderAudioProps): UseReaderAudioReturn {
  const {
    narrationState,
    loadNarration: loadNarrationAudio,
    playNarration,
    pauseNarration,
    soundscapeState,
    loadSoundscape: loadSoundscapeAudio,
    playSoundscape,
    pauseSoundscape,
    crossfadeSoundscape,
    fadeOutSoundscape,
    cleanup: cleanupAudio,
  } = useAudioPlayer();

  const { preferences } = useLocalPreferences();

  const [isNarrationActive, setIsNarrationActive] = useState(false);
  const [isSoundscapeActive, setIsSoundscapeActive] = useState(false);

  const introFadeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const introFadedPages = useRef(new Set<number>());
  const prevSoundscapeUrl = useRef<string | null>(null);

  const currentPage = pageData?.pageNumber ?? 1;

  const narrationAssignment = pageData?.assignments?.find((a) => a.audioType === 'narration');
  const soundscapeAssignment = pageData?.assignments?.find((a) => a.audioType === 'soundscape');
  const narrationUrl = narrationAssignment?.audioUrl || pageData?.narrationUrl;
  const soundscapeUrl = soundscapeAssignment?.audioUrl;

  // Load narration audio when page changes
  useEffect(() => {
    if (narrationUrl) {
      loadNarrationAudio(narrationUrl).then(() => {
        if (isNarrationActive) {
          playNarration();
        }
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [narrationUrl]);

  // Handle soundscape changes with crossfade
  useEffect(() => {
    if (!soundscapeUrl) return;

    if (prevSoundscapeUrl.current && prevSoundscapeUrl.current !== soundscapeUrl && isSoundscapeActive) {
      crossfadeSoundscape(soundscapeUrl);
    } else if (!prevSoundscapeUrl.current || prevSoundscapeUrl.current !== soundscapeUrl) {
      loadSoundscapeAudio(soundscapeUrl).then(() => {
        if (isSoundscapeActive) playSoundscape();
      });
    }
    prevSoundscapeUrl.current = soundscapeUrl;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [soundscapeUrl]);

  // Intro-only mode: fade out after 10 seconds
  useEffect(() => {
    if (introFadeTimerRef.current) {
      clearTimeout(introFadeTimerRef.current);
      introFadeTimerRef.current = null;
    }

    if (
      preferences.soundscapeMode === 'intro-only' &&
      isSoundscapeActive &&
      soundscapeUrl &&
      !introFadedPages.current.has(currentPage)
    ) {
      introFadeTimerRef.current = setTimeout(() => {
        introFadedPages.current.add(currentPage);
        fadeOutSoundscape(3000).then(() => {
          setIsSoundscapeActive(false);
        });
      }, 10000);
    }

    return () => {
      if (introFadeTimerRef.current) clearTimeout(introFadeTimerRef.current);
    };
  }, [currentPage, preferences.soundscapeMode, isSoundscapeActive, soundscapeUrl, fadeOutSoundscape]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      cleanupAudio();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const toggleNarration = useCallback(async () => {
    if (isNarrationActive) {
      await pauseNarration();
      setIsNarrationActive(false);
    } else if (narrationUrl) {
      await playNarration();
      setIsNarrationActive(true);
    }
  }, [isNarrationActive, narrationUrl, playNarration, pauseNarration]);

  const toggleSoundscape = useCallback(async () => {
    if (isSoundscapeActive) {
      await pauseSoundscape();
      setIsSoundscapeActive(false);
    } else if (soundscapeUrl) {
      await playSoundscape();
      setIsSoundscapeActive(true);
    }
  }, [isSoundscapeActive, soundscapeUrl, playSoundscape, pauseSoundscape]);

  const loadNarration = useCallback(
    async (url: string) => {
      await loadNarrationAudio(url);
    },
    [loadNarrationAudio]
  );

  const loadSoundscape = useCallback(
    async (url: string) => {
      await loadSoundscapeAudio(url);
    },
    [loadSoundscapeAudio]
  );

  const cleanup = useCallback(() => {
    if (introFadeTimerRef.current) {
      clearTimeout(introFadeTimerRef.current);
      introFadeTimerRef.current = null;
    }
    cleanupAudio();
  }, [cleanupAudio]);

  return {
    isNarrationActive,
    isSoundscapeActive,
    narrationState,
    soundscapeState,
    toggleNarration,
    toggleSoundscape,
    loadNarration,
    loadSoundscape,
    cleanup,
  };
}
