import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { BlurView } from 'expo-blur';
import Animated, {
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';
import { fonts } from '@/lib/theme';

type Props = {
  hasNarration: boolean;
  hasSoundscape: boolean;
  isNarrationPlaying: boolean;
  isSoundscapePlaying: boolean;
  onToggleNarration: () => void;
  onToggleSoundscape: () => void;
};

export const AudioControls = React.memo(function AudioControls({
  hasNarration,
  hasSoundscape,
  isNarrationPlaying,
  isSoundscapePlaying,
  onToggleNarration,
  onToggleSoundscape,
}: Props) {
  const visible = hasNarration || hasSoundscape;

  const containerStyle = useAnimatedStyle(() => ({
    opacity: withTiming(visible ? 1 : 0, { duration: 200 }),
  }));

  return (
    <Animated.View
      style={[styles.container, containerStyle]}
      pointerEvents={visible ? 'auto' : 'none'}
    >
      <View style={styles.pillRow}>
        {hasNarration && (
          <TouchableOpacity onPress={onToggleNarration} activeOpacity={0.7} hitSlop={16}>
            <BlurView
              intensity={40}
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
                    color: isNarrationPlaying ? '#ffffff' : 'rgba(255,255,255,0.8)',
                    fontFamily: fonts.sans,
                  },
                ]}
              >
                {isNarrationPlaying ? 'Reading' : 'Read'}
              </Text>
            </BlurView>
          </TouchableOpacity>
        )}

        {hasSoundscape && (
          <TouchableOpacity onPress={onToggleSoundscape} activeOpacity={0.7} hitSlop={16}>
            <BlurView
              intensity={40}
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
                    color: isSoundscapePlaying ? '#ffffff' : 'rgba(255,255,255,0.8)',
                    fontFamily: fonts.sans,
                  },
                ]}
              >
                {isSoundscapePlaying ? 'BGM On' : 'BGM'}
              </Text>
            </BlurView>
          </TouchableOpacity>
        )}
      </View>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 100,
    left: 0,
    right: 0,
    zIndex: 40,
    alignItems: 'center',
  },
  pillRow: {
    flexDirection: 'row',
    gap: 8,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 20,
    paddingHorizontal: 20,
    borderRadius: 28,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.15)',
    overflow: 'hidden',
    minHeight: 56,
  },
  pillActiveNarration: {
    backgroundColor: 'rgba(249, 115, 22, 0.85)',
    borderColor: 'rgba(251, 146, 60, 0.6)',
  },
  pillActiveSoundscape: {
    backgroundColor: 'rgba(20, 184, 166, 0.85)',
    borderColor: 'rgba(45, 212, 191, 0.6)',
  },
  pillEmoji: {
    fontSize: 14,
  },
  pillText: {
    fontSize: 11,
    fontWeight: '700',
  },
});
