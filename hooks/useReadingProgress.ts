import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useCallback } from 'react';
import { AppState, type AppStateStatus } from 'react-native';
import { fetchReadingProgress, saveReadingProgress } from '@/lib/api';
import { getLocalProgress, setLocalProgress } from '@/lib/storage';
import { useAuth } from '@/providers/AuthProvider';
import type { ReadingProgress } from '@/types';

export function useReadingProgress(bookId: string) {
  return useQuery<ReadingProgress | null>({
    queryKey: ['reading-progress', bookId],
    queryFn: () => fetchReadingProgress(bookId),
    enabled: !!bookId,
  });
}

export function useSaveProgress() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: saveReadingProgress,
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({
        queryKey: ['reading-progress', variables.bookId],
      });
    },
  });
}

type AutoSaveOptions = {
  bookId: string;
  currentPage: number;
  totalPages: number;
  enabled?: boolean;
};

export function useAutoSaveProgress({
  bookId,
  currentPage,
  totalPages,
  enabled = true,
}: AutoSaveOptions) {
  const { isAuthenticated } = useAuth();
  const saveProgressMutation = useSaveProgress();
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastSavedRef = useRef<{ page: number; bookId: string } | null>(null);

  const saveNow = useCallback(() => {
    if (
      lastSavedRef.current?.page === currentPage &&
      lastSavedRef.current?.bookId === bookId
    ) {
      return;
    }

    if (isAuthenticated) {
      saveProgressMutation.mutate({ bookId, currentPage, totalPages });
    } else {
      setLocalProgress(bookId, { currentPage, totalPages });
    }

    lastSavedRef.current = { page: currentPage, bookId };
  }, [bookId, currentPage, totalPages, isAuthenticated, saveProgressMutation]);

  // Debounced auto-save on page change
  useEffect(() => {
    if (!enabled || !bookId || currentPage <= 0 || totalPages <= 0) return;

    if (timeoutRef.current) clearTimeout(timeoutRef.current);

    timeoutRef.current = setTimeout(() => {
      saveNow();
    }, 2000);

    return () => {
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [bookId, currentPage, totalPages, enabled, saveNow]);

  // Save immediately when app goes to background
  useEffect(() => {
    const handleAppState = (nextState: AppStateStatus) => {
      if (nextState === 'background' || nextState === 'inactive') {
        if (
          enabled &&
          bookId &&
          currentPage > 0 &&
          (lastSavedRef.current?.page !== currentPage ||
            lastSavedRef.current?.bookId !== bookId)
        ) {
          saveNow();
        }
      }
    };

    const subscription = AppState.addEventListener('change', handleAppState);
    return () => subscription.remove();
  }, [bookId, currentPage, enabled, saveNow]);
}
