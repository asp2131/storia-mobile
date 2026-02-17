import { useRef, useCallback, useEffect, useState } from 'react';
import { Audio, type AVPlaybackStatus } from 'expo-av';

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
  const narrationRef = useRef<Audio.Sound | null>(null);
  const soundscapeRef = useRef<Audio.Sound | null>(null);
  const fadeIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

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
    Audio.setAudioModeAsync({
      playsInSilentModeIOS: true,
      staysActiveInBackground: true,
      shouldDuckAndroid: true,
    });
  }, []);

  const handleNarrationStatus = useCallback((status: AVPlaybackStatus) => {
    if (!status.isLoaded) return;
    setNarrationState({
      isPlaying: status.isPlaying,
      positionMs: status.positionMillis,
      durationMs: status.durationMillis ?? 0,
    });
  }, []);

  const handleSoundscapeStatus = useCallback((status: AVPlaybackStatus) => {
    if (!status.isLoaded) return;
    setSoundscapeState({
      isPlaying: status.isPlaying,
      positionMs: status.positionMillis,
      durationMs: status.durationMillis ?? 0,
    });
  }, []);

  // Narration controls
  const loadNarration = useCallback(async (uri: string) => {
    if (narrationRef.current) {
      await narrationRef.current.unloadAsync();
    }
    const { sound } = await Audio.Sound.createAsync(
      { uri },
      { shouldPlay: false, progressUpdateIntervalMillis: 50 },
      handleNarrationStatus
    );
    narrationRef.current = sound;
  }, [handleNarrationStatus]);

  const playNarration = useCallback(async () => {
    await narrationRef.current?.playAsync();
  }, []);

  const pauseNarration = useCallback(async () => {
    await narrationRef.current?.pauseAsync();
  }, []);

  const seekNarration = useCallback(async (positionMs: number) => {
    await narrationRef.current?.setPositionAsync(positionMs);
  }, []);

  const setNarrationVolume = useCallback(async (volume: number) => {
    await narrationRef.current?.setVolumeAsync(volume);
  }, []);

  // Soundscape controls
  const loadSoundscape = useCallback(async (uri: string) => {
    if (soundscapeRef.current) {
      await soundscapeRef.current.unloadAsync();
    }
    const { sound } = await Audio.Sound.createAsync(
      { uri },
      { shouldPlay: false, isLooping: true, volume: 0.6 },
      handleSoundscapeStatus
    );
    soundscapeRef.current = sound;
  }, [handleSoundscapeStatus]);

  const playSoundscape = useCallback(async () => {
    await soundscapeRef.current?.playAsync();
  }, []);

  const pauseSoundscape = useCallback(async () => {
    await soundscapeRef.current?.pauseAsync();
  }, []);

  const setSoundscapeVolume = useCallback(async (volume: number) => {
    await soundscapeRef.current?.setVolumeAsync(volume);
  }, []);

  // Fade out over duration
  const fadeOutSoundscape = useCallback(async (duration: number = 3000) => {
    const sound = soundscapeRef.current;
    if (!sound) return;

    const status = await sound.getStatusAsync();
    if (!status.isLoaded) return;

    const startVolume = status.volume;
    const steps = 20;
    const stepDuration = duration / steps;
    const volumeStep = startVolume / steps;
    let currentStep = 0;

    if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

    return new Promise<void>((resolve) => {
      fadeIntervalRef.current = setInterval(async () => {
        currentStep++;
        const newVolume = Math.max(0, startVolume - volumeStep * currentStep);
        await sound.setVolumeAsync(newVolume);

        if (currentStep >= steps) {
          if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);
          await sound.pauseAsync();
          resolve();
        }
      }, stepDuration);
    });
  }, []);

  // Crossfade: fade out current, load new, fade in
  const crossfadeSoundscape = useCallback(async (newUri: string, duration: number = 1500) => {
    const oldSound = soundscapeRef.current;

    // Load new sound at volume 0
    const { sound: newSound } = await Audio.Sound.createAsync(
      { uri: newUri },
      { shouldPlay: true, isLooping: true, volume: 0 },
      handleSoundscapeStatus
    );

    // Fade out old, fade in new simultaneously
    const steps = 15;
    const stepDuration = duration / steps;
    let currentStep = 0;

    if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

    return new Promise<void>((resolve) => {
      fadeIntervalRef.current = setInterval(async () => {
        currentStep++;
        const progress = currentStep / steps;

        // Fade in new
        await newSound.setVolumeAsync(0.6 * progress);

        // Fade out old
        if (oldSound) {
          try {
            await oldSound.setVolumeAsync(0.6 * (1 - progress));
          } catch {
            // Old sound may already be unloaded
          }
        }

        if (currentStep >= steps) {
          if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

          // Cleanup old
          if (oldSound) {
            try {
              await oldSound.unloadAsync();
            } catch {
              // Ignore
            }
          }

          soundscapeRef.current = newSound;
          resolve();
        }
      }, stepDuration);
    });
  }, [handleSoundscapeStatus]);

  // Cleanup all audio
  const cleanup = useCallback(async () => {
    if (fadeIntervalRef.current) clearInterval(fadeIntervalRef.current);

    if (narrationRef.current) {
      try {
        await narrationRef.current.unloadAsync();
      } catch { /* ignore */ }
      narrationRef.current = null;
    }

    if (soundscapeRef.current) {
      try {
        await soundscapeRef.current.unloadAsync();
      } catch { /* ignore */ }
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
