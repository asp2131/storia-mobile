import { useState, useEffect, useCallback } from 'react';
import { getPreferences, setPreferences } from '@/lib/storage';
import type { ReaderPreferences, SoundscapeMode } from '@/types';

const STORAGE_KEY = 'storia-reader-preferences';

const defaultPreferences: ReaderPreferences = {
  soundscapeMode: 'continuous',
  soundscapeEnabled: true,
  hasSeenNavigationHint: false,
};

export function useLocalPreferences() {
  const [preferences, setPrefs] = useState<ReaderPreferences>(defaultPreferences);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    getPreferences<ReaderPreferences>(STORAGE_KEY).then((stored) => {
      if (stored) {
        setPrefs({ ...defaultPreferences, ...stored });
      }
      setIsLoaded(true);
    });
  }, []);

  const savePreferences = useCallback((updates: Partial<ReaderPreferences>) => {
    setPrefs((prev) => {
      const next = { ...prev, ...updates };
      setPreferences(next, STORAGE_KEY);
      return next;
    });
  }, []);

  const setSoundscapeMode = useCallback(
    (mode: SoundscapeMode) => savePreferences({ soundscapeMode: mode }),
    [savePreferences]
  );

  const setSoundscapeEnabled = useCallback(
    (enabled: boolean) => savePreferences({ soundscapeEnabled: enabled }),
    [savePreferences]
  );

  const setHasSeenNavigationHint = useCallback(
    (seen: boolean) => savePreferences({ hasSeenNavigationHint: seen }),
    [savePreferences]
  );

  return {
    preferences,
    isLoaded,
    setSoundscapeMode,
    setSoundscapeEnabled,
    setHasSeenNavigationHint,
  };
}
