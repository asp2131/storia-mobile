import React, { createContext, useContext, useState, useCallback, useMemo, useEffect, useRef, ReactNode } from 'react';
import { useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { useSharedValue } from 'react-native-reanimated';
import { useReaderData } from '@/hooks/useBookData';
import { useReadingProgress, useAutoSaveProgress } from '@/hooks/useReadingProgress';
import { useAudioManager } from '@/hooks/useAudioManager';
import { useLocalPreferences } from '@/hooks/useLocalPreferences';
import { usePageAnimatedStyle } from '@/hooks/useReaderAnimations';
import type { PageData, ReaderResponse } from '@/types';

type AudioPlayerState = {
  isPlaying: boolean;
  positionMs: number;
  durationMs: number;
};

interface ReaderContextValue {
  // Page state
  activeIndex: number;
  totalPages: number;
  currentPage: number;
  progressPercent: number;
  pages: PageData[];

  // Audio state
  isNarrationActive: boolean;
  isSoundscapeActive: boolean;
  narrationState: AudioPlayerState;
  soundscapeState: AudioPlayerState;

  // UI visibility state
  isUIVisible: boolean;

  // Actions
  goToPage: (index: number) => void;
  toggleNarration: () => void;
  toggleSoundscape: () => void;
  handleClose: () => void;
  toggleUI: () => void;
  showUI: () => void;
  hideUI: () => void;

  // Data
  readerData: ReaderResponse | undefined;
  isLoading: boolean;
  error: Error | null;

  // Utility
  visiblePageIndices: number[];

  // Internal (for gesture handling)
  translateY: ReturnType<typeof useSharedValue<number>>;
  activeIndexShared: ReturnType<typeof useSharedValue<number>>;
  getPageAnimatedStyle: ReturnType<typeof usePageAnimatedStyle>;
  setActiveIndexInternal: (index: number) => void;

  // Audio URLs for current page
  narrationUrl: string | null;
  soundscapeUrl: string | null;
}

const ReaderContext = createContext<ReaderContextValue | null>(null);

interface ReaderProviderProps {
  bookId: string;
  children: ReactNode;
}

export function ReaderProvider({ bookId, children }: ReaderProviderProps) {
  const router = useRouter();

  // Data
  const { data: readerData, isLoading, error } = useReaderData(bookId);
  const { data: savedProgress } = useReadingProgress(bookId);

  // State
  const [activeIndex, setActiveIndex] = useState(0);
  const [isUIVisible, setIsUIVisible] = useState(true);
  const progressRestoredRef = useRef(false);

  // Shared values for gestures
  const translateY = useSharedValue(0);
  const activeIndexShared = useSharedValue(0);
  const getPageAnimatedStyle = usePageAnimatedStyle(translateY, activeIndexShared);

  // Derived data (must be before useAudioManager)
  const pages = useMemo(
    () => [...(readerData?.pages ?? [])].sort((a, b) => a.pageNumber - b.pageNumber),
    [readerData?.pages]
  );
  const totalPages = pages.length;
  const currentPage = pages[activeIndex]?.pageNumber ?? 1;
  const pageData: PageData | undefined = pages[activeIndex];
  const progressPercent = totalPages > 0 ? ((activeIndex + 1) / totalPages) * 100 : 0;

  const narrationAssignment = pageData?.assignments?.find((a) => a.audioType === 'narration');
  const soundscapeAssignment = pageData?.assignments?.find((a) => a.audioType === 'soundscape');
  const narrationUrl = narrationAssignment?.audioUrl || pageData?.narrationUrl || null;
  const soundscapeUrl = soundscapeAssignment?.audioUrl || null;

  // Audio - using useAudioManager for simplified audio management
  const {
    isNarrationActive,
    isSoundscapeActive,
    narrationState,
    soundscapeState,
    isTransitioning,
    toggleNarration,
    toggleSoundscape,
    cleanup,
  } = useAudioManager({
    pageData,
    bookId,
    pageNumber: currentPage,
  });

  // Visible pages (virtualization window of ±1)
  const visiblePageIndices = useMemo(() => {
    const indices: number[] = [];
    for (let i = Math.max(0, activeIndex - 1); i <= Math.min(totalPages - 1, activeIndex + 1); i++) {
      indices.push(i);
    }
    return indices;
  }, [activeIndex, totalPages]);

  // Auto-save progress
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

  // Actions
  const goToPage = useCallback((index: number) => {
    if (index >= 0 && index < totalPages) {
      setActiveIndex(index);
      activeIndexShared.value = index;
      translateY.value = 0;
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    }
  }, [totalPages, activeIndexShared, translateY]);

  const handleClose = useCallback(async () => {
    await cleanup();
    router.back();
  }, [router, cleanup]);

  // Internal setter for gesture handling
  const setActiveIndexInternal = useCallback((index: number) => {
    setActiveIndex(index);
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  }, []);

  // UI visibility actions
  const toggleUI = useCallback(() => {
    setIsUIVisible((prev) => {
      const newValue = !prev;
      Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
      return newValue;
    });
  }, []);

  const showUI = useCallback(() => {
    setIsUIVisible(true);
  }, []);

  const hideUI = useCallback(() => {
    setIsUIVisible(false);
  }, []);

  const value: ReaderContextValue = {
    // Page state
    activeIndex,
    totalPages,
    currentPage,
    progressPercent,
    pages,

    // Audio state
    isNarrationActive,
    isSoundscapeActive,
    narrationState,
    soundscapeState,

    // UI visibility state
    isUIVisible,

    // Actions
    goToPage,
    toggleNarration,
    toggleSoundscape,
    handleClose,
    toggleUI,
    showUI,
    hideUI,

    // Data
    readerData,
    isLoading,
    error,

    // Utility
    visiblePageIndices,

    // Internal
    translateY,
    activeIndexShared,
    getPageAnimatedStyle,
    setActiveIndexInternal,

    // Audio URLs
    narrationUrl,
    soundscapeUrl,
  };

  return <ReaderContext.Provider value={value}>{children}</ReaderContext.Provider>;
}

export function useReader() {
  const context = useContext(ReaderContext);
  if (!context) {
    throw new Error('useReader must be used within a ReaderProvider');
  }
  return context;
}
