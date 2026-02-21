import { useRef, useCallback, useEffect, useState } from 'react';
import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from 'expo-audio';

export type AudioPlayerState = {
  isPlaying: boolean;
  positionMs: number;
  durationMs: number;
};

type UseAudioPlayerReturn = {
  // Narration
  narrationState: AudioPlayerState;
  loadNarration: (uri: string) => Promise<void>;
  playNarration: () => Promise<void>;
  pauseNarration: () => Promise<void>;
  seekNarration: (positionMs: number) => Promise<void>;
  setNarrationVolume: (volume: number) => Promise<void>;
  // Soundscape
  soundscapeState: AudioPlayerState;
  loadSoundscape: (uri: string) => Promise<void>;
  playSoundscape: () => Promise<void>;
  pauseSoundscape: () => Promise<void>;
  setSoundscapeVolume: (volume: number) => Promise<void>;
  // Crossfade
  crossfadeSoundscape: (newUri: string, duration?: number) => Promise<void>;
  fadeOutSoundscape: (duration?: number) => Promise<void>;
  // Cleanup
  cleanup: () => Promise<void>;
};

export function useAudioPlayer(): UseAudioPlayerReturn {
  const narrationRef = useRef<AudioPlayer | null>(null);
  const soundscapeRef = useRef<AudioPlayer | null>(null);
  const narrationSubRef = useRef<ReturnType<AudioPlayer['addListener']> | null>(null);
  const soundscapeSubRef = useRef<ReturnType<AudioPlayer['addListener']> | null>(null);
  const fadeIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  // Track the current soundscape volume for fade calculations
  const soundscapeVolumeRef = useRef<number>(0.6);

  const [narrationState, setNarrationState] = useState<AudioPlayerState>({
    isPlaying: false,
    positionMs: 0,
    durationMs: 0,
  });

  const [soundscapeState, setSoundscapeState] = useState<AudioPlayerState>({
    isPlaying: false,
    positionMs: 0,
    durationMs: 0,
  });

  // Configure audio mode for background playback
  useEffect(() => {
    setAudioModeAsync({
      playsInSilentMode: true,
      interruptionMode: 'mixWithOthers',
      allowsRecording: false,
    });
  }, []);

  // Narration controls
  const loadNarration = useCallback(async (uri: string) => {
    // Clean up previous narration player
    if (narrationSubRef.current) {
      narrationSubRef.current.remove();
      narrationSubRef.current = null;
    }
    if (narrationRef.current) {
      narrationRef.current.remove();
      narrationRef.current = null;
    }

    const player = createAudioPlayer({ uri });

    // Subscribe to status updates for word-sync (high frequency)
    narrationSubRef.current = player.addListener('playbackStatusUpdate', (status) => {
      setNarrationState({
        isPlaying: status.playing,
        positionMs: (status.currentTime ?? 0) * 1000,
        durationMs: (status.duration ?? 0) * 1000,
      });
    });

    narrationRef.current = player;
  }, []);

  const playNarration = useCallback(async () => {
    narrationRef.current?.play();
  }, []);

  const pauseNarration = useCallback(async () => {
    narrationRef.current?.pause();
  }, []);

  const seekNarration = useCallback(async (positionMs: number) => {
    narrationRef.current?.seekTo(positionMs / 1000);
  }, []);

  const setNarrationVolume = useCallback(async (volume: number) => {
    if (narrationRef.current) {
      narrationRef.current.volume = volume;
    }
  }, []);

  // Soundscape controls
  const loadSoundscape = useCallback(async (uri: string) => {
    // Clean up previous soundscape player
    if (soundscapeSubRef.current) {
      soundscapeSubRef.current.remove();
      soundscapeSubRef.current = null;
    }
    if (soundscapeRef.current) {
      soundscapeRef.current.remove();
      soundscapeRef.current = null;
    }

    const player = createAudioPlayer({ uri });
    player.loop = true;
    player.volume = 0.6;
    soundscapeVolumeRef.current = 0.6;

    soundscapeSubRef.current = player.addListener('playbackStatusUpdate', (status) => {
      setSoundscapeState({
        isPlaying: status.playing,
        positionMs: (status.currentTime ?? 0) * 1000,
        durationMs: (status.duration ?? 0) * 1000,
      });
    });

    soundscapeRef.current = player;
  }, []);

  const playSoundscape = useCallback(async () => {
    soundscapeRef.current?.play();
  }, []);

  const pauseSoundscape = useCallback(async () => {
    soundscapeRef.current?.pause();
  }, []);

  const setSoundscapeVolume = useCallback(async (volume: number) => {
    if (soundscapeRef.current) {
      soundscapeRef.current.volume = volume;
      soundscapeVolumeRef.current = volume;
    }
  }, []);

  // Fade out over duration
  const fadeOutSoundscape = useCallback(async (duration: number = 3000) => {
    const player = soundscapeRef.current;
    if (!player) return;

    const startVolume = soundscapeVolumeRef.current;
    const steps = 20;
    const stepDuration = duration / steps;
    const volumeStep = startVolume / steps;
    let currentStep = 0;

    if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

    return new Promise<void>((resolve) => {
      fadeIntervalRef.current = setInterval(() => {
        currentStep++;
        const newVolume = Math.max(0, startVolume - volumeStep * currentStep);
        player.volume = newVolume;
        soundscapeVolumeRef.current = newVolume;

        if (currentStep >= steps) {
          if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);
          player.pause();
          resolve();
        }
      }, stepDuration);
    });
  }, []);

  // Crossfade: fade out current, load new, fade in
  const crossfadeSoundscape = useCallback(async (newUri: string, duration: number = 1500) => {
    const oldPlayer = soundscapeRef.current;
    const oldSub = soundscapeSubRef.current;

    // Create new player at volume 0
    const newPlayer = createAudioPlayer({ uri: newUri });
    newPlayer.loop = true;
    newPlayer.volume = 0;

    // Subscribe new player to status updates
    soundscapeSubRef.current = newPlayer.addListener('playbackStatusUpdate', (status) => {
      setSoundscapeState({
        isPlaying: status.playing,
        positionMs: (status.currentTime ?? 0) * 1000,
        durationMs: (status.duration ?? 0) * 1000,
      });
    });

    // Start playing new sound
    newPlayer.play();

    // Fade out old, fade in new simultaneously
    const steps = 15;
    const stepDuration = duration / steps;
    let currentStep = 0;

    if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

    return new Promise<void>((resolve) => {
      fadeIntervalRef.current = setInterval(() => {
        currentStep++;
        const progress = currentStep / steps;

        // Fade in new
        newPlayer.volume = 0.6 * progress;

        // Fade out old
        if (oldPlayer) {
          try {
            oldPlayer.volume = 0.6 * (1 - progress);
          } catch {
            // Old player may already be removed
          }
        }

        if (currentStep >= steps) {
          if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

          // Cleanup old
          if (oldSub) {
            try { oldSub.remove(); } catch { /* ignore */ }
          }
          if (oldPlayer) {
            try { oldPlayer.remove(); } catch { /* ignore */ }
          }

          soundscapeRef.current = newPlayer;
          soundscapeVolumeRef.current = 0.6;
          resolve();
        }
      }, stepDuration);
    });
  }, []);

  // Cleanup all audio
  const cleanup = useCallback(async () => {
    if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

    if (narrationSubRef.current) {
      try { narrationSubRef.current.remove(); } catch { /* ignore */ }
      narrationSubRef.current = null;
    }
    if (narrationRef.current) {
      try { narrationRef.current.remove(); } catch { /* ignore */ }
      narrationRef.current = null;
    }

    if (soundscapeSubRef.current) {
      try { soundscapeSubRef.current.remove(); } catch { /* ignore */ }
      soundscapeSubRef.current = null;
    }
    if (soundscapeRef.current) {
      try { soundscapeRef.current.remove(); } catch { /* ignore */ }
      soundscapeRef.current = null;
    }

    setNarrationState({ isPlaying: false, positionMs: 0, durationMs: 0 });
    setSoundscapeState({ isPlaying: false, positionMs: 0, durationMs: 0 });
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      cleanup();
    };
  }, [cleanup]);

  return {
    narrationState,
    loadNarration,
    playNarration,
    pauseNarration,
    seekNarration,
    setNarrationVolume,
    soundscapeState,
    loadSoundscape,
    playSoundscape,
    pauseSoundscape,
    setSoundscapeVolume,
    crossfadeSoundscape,
    fadeOutSoundscape,
    cleanup,
  };
}
