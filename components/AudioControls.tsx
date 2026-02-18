import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { BlurView } from 'expo-blur';
import Animated, {
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { fonts } from '@/lib/theme';

type Props = {
  hasNarration: boolean;
  hasSoundscape: boolean;
  isNarrationPlaying: boolean;
  isSoundscapePlaying: boolean;
  onToggleNarration: () => void;
  onToggleSoundscape: () => void;
  isVisible?: boolean;
};

export const AudioControls = React.memo(function AudioControls({
  hasNarration,
  hasSoundscape,
  isNarrationPlaying,
  isSoundscapePlaying,
  onToggleNarration,
  onToggleSoundscape,
  isVisible = true,
}: Props) {
  const insets = useSafeAreaInsets();
  const hasAudio = hasNarration || hasSoundscape;
  const shouldShow = hasAudio && isVisible;

  const containerStyle = useAnimatedStyle(() => ({
    opacity: withTiming(shouldShow ? 1 : 0, { duration: 250 }),
    transform: [{ translateY: withTiming(shouldShow ? 0 : 20, { duration: 250 }) }],
  }));

  return (
    <Animated.View
      style={[
        styles.container,
        { bottom: Math.max(24, insets.bottom + 8) },
        containerStyle,
      ]}
      pointerEvents={shouldShow ? 'auto' : 'none'}
    >
      <BlurView
        intensity={50}
        tint="dark"
        style={styles.backgroundBlur}
      >
        <View style={styles.pillRow}>
          {hasNarration && (
            <TouchableOpacity onPress={onToggleNarration} activeOpacity={0.7} hitSlop={20}>
              <BlurView
                intensity={30}
                tint="dark"
                style={[
                  styles.pill,
                  isNarrationPlaying && styles.pillActiveNarration,
                ]}
              >
                <Text style={styles.pillEmoji}>
                  {isNarrationPlaying ? '\u{23F8}' : '\u{1F3A4}'}
                </Text>
                <Text
                  style={[
                    styles.pillText,
                    {
                      color: isNarrationPlaying ? '#ffffff' : 'rgba(255,255,255,0.85)',
                      fontFamily: fonts.sans,
                    },
                  ]}
                >
                  {isNarrationPlaying ? 'Pause' : 'Read'}
                </Text>
              </BlurView>
            </TouchableOpacity>
          )}

          {hasSoundscape && (
            <TouchableOpacity onPress={onToggleSoundscape} activeOpacity={0.7} hitSlop={20}>
              <BlurView
                intensity={30}
                tint="dark"
                style={[
                  styles.pill,
                  isSoundscapePlaying && styles.pillActiveSoundscape,
                ]}
              >
                <Text style={styles.pillEmoji}>
                  {isSoundscapePlaying ? '\u{1F50A}' : '\u{1F3B5}'}
                </Text>
                <Text
                  style={[
                    styles.pillText,
                    {
                      color: isSoundscapePlaying ? '#ffffff' : 'rgba(255,255,255,0.85)',
                      fontFamily: fonts.sans,
                    },
                  ]}
                >
                  {isSoundscapePlaying ? 'Mute' : 'Sound'}
                </Text>
              </BlurView>
            </TouchableOpacity>
          )}
        </View>
      </BlurView>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    left: 0,
    right: 0,
    zIndex: 40,
    alignItems: 'center',
    paddingHorizontal: 16,
  },
  backgroundBlur: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 32,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  pillRow: {
    flexDirection: 'row',
    gap: 10,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingVertical: 14,
    paddingHorizontal: 20,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.12)',
    overflow: 'hidden',
    minHeight: 52,
    minWidth: 100,
    justifyContent: 'center',
  },
  pillActiveNarration: {
    backgroundColor: 'rgba(249, 115, 22, 0.9)',
    borderColor: 'rgba(251, 146, 60, 0.7)',
  },
  pillActiveSoundscape: {
    backgroundColor: 'rgba(20, 184, 166, 0.9)',
    borderColor: 'rgba(45, 212, 191, 0.7)',
  },
  pillEmoji: {
    fontSize: 18,
  },
  pillText: {
    fontSize: 14,
    fontWeight: '600',
    letterSpacing: 0.3,
  },
});
