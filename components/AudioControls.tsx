import React, { useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ActivityIndicator } from 'react-native';
import { BlurView } from 'expo-blur';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withTiming,
  withRepeat,
  withSequence,
  Easing,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { fonts } from '@/lib/theme';

// Accent colors
const NARRATION_COLOR = '#F59E0B'; // Warm amber
const NARRATION_GLOW = 'rgba(245, 158, 11, 0.25)';
const SOUNDSCAPE_COLOR = '#14B8A6'; // Teal
const SOUNDSCAPE_GLOW = 'rgba(20, 184, 166, 0.25)';

type Props = {
  hasNarration: boolean;
  hasSoundscape: boolean;
  isNarrationPlaying: boolean;
  isSoundscapePlaying: boolean;
  onToggleNarration: () => void;
  onToggleSoundscape: () => void;
  isVisible?: boolean;
  isTransitioning?: boolean;
};

/**
 * Pulsing dot indicator that shows when audio is playing.
 */
function PulsingDot({ color, isActive }: { color: string; isActive: boolean }) {
  const pulse = useSharedValue(1);

  useEffect(() => {
    if (isActive) {
      pulse.value = withRepeat(
        withSequence(
          withTiming(0.4, { duration: 800, easing: Easing.inOut(Easing.ease) }),
          withTiming(1, { duration: 800, easing: Easing.inOut(Easing.ease) })
        ),
        -1,
        true
      );
    } else {
      pulse.value = withTiming(0, { duration: 200 });
    }
  }, [isActive, pulse]);

  const dotStyle = useAnimatedStyle(() => ({
    opacity: pulse.value,
    transform: [{ scale: 0.6 + pulse.value * 0.4 }],
  }));

  return (
    <Animated.View
      style={[
        {
          position: 'absolute',
          top: 6,
          right: 6,
          width: 6,
          height: 6,
          borderRadius: 3,
          backgroundColor: color,
        },
        dotStyle,
      ]}
    />
  );
}

/**
 * A single circular icon button for audio control.
 */
function AudioIconButton({
  icon,
  accentColor,
  glowColor,
  isPlaying,
  onPress,
}: {
  icon: string;
  accentColor: string;
  glowColor: string;
  isPlaying: boolean;
  onPress: () => void;
}) {
  const glowOpacity = useSharedValue(0);

  useEffect(() => {
    glowOpacity.value = withTiming(isPlaying ? 1 : 0, { duration: 300 });
  }, [isPlaying, glowOpacity]);

  const glowStyle = useAnimatedStyle(() => ({
    opacity: glowOpacity.value,
  }));

  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.7}
      hitSlop={12}
      style={styles.iconButtonWrapper}
    >
      {/* Glow ring behind button when active */}
      <Animated.View
        style={[
          styles.glowRing,
          { backgroundColor: glowColor },
          glowStyle,
        ]}
      />
      <View
        style={[
          styles.iconButton,
          isPlaying && {
            borderColor: accentColor,
            borderWidth: 1.5,
          },
        ]}
      >
        <Text
          style={[
            styles.iconText,
            { color: isPlaying ? accentColor : 'rgba(255,255,255,0.7)' },
          ]}
        >
          {icon}
        </Text>
        <PulsingDot color={accentColor} isActive={isPlaying} />
      </View>
    </TouchableOpacity>
  );
}

export const AudioControls = React.memo(function AudioControls({
  hasNarration,
  hasSoundscape,
  isNarrationPlaying,
  isSoundscapePlaying,
  onToggleNarration,
  onToggleSoundscape,
  isVisible = true,
  isTransitioning = false,
}: Props) {
  const insets = useSafeAreaInsets();
  const hasAudio = hasNarration || hasSoundscape;
  const shouldShow = hasAudio && isVisible;

  const containerStyle = useAnimatedStyle(() => ({
    opacity: withTiming(shouldShow ? 1 : 0, { duration: 300 }),
    transform: [{ translateY: withTiming(shouldShow ? 0 : 16, { duration: 300 }) }],
  }));

  if (!hasAudio) return null;

  // Show loading state during audio transitions
  if (isTransitioning) {
    return (
      <Animated.View
        style={[
          styles.container,
          { bottom: Math.max(28, insets.bottom + 12) },
          containerStyle,
        ]}
      >
        <BlurView
          intensity={35}
          tint="dark"
          style={styles.loadingContainer}
        >
          <ActivityIndicator size="small" color="rgba(255,255,255,0.8)" />
          <Text style={styles.loadingText}>Loading audio...</Text>
        </BlurView>
      </Animated.View>
    );
  }

  return (
    <Animated.View
      style={[
        styles.container,
        { bottom: Math.max(28, insets.bottom + 12) },
        containerStyle,
      ]}
      pointerEvents={shouldShow ? 'auto' : 'none'}
    >
      <BlurView
        intensity={35}
        tint="dark"
        style={styles.pillContainer}
      >
        <View style={styles.buttonsRow}>
          {hasNarration && (
            <AudioIconButton
              icon={isNarrationPlaying ? '\u23F8' : '\uD83C\uDFA4'}
              accentColor={NARRATION_COLOR}
              glowColor={NARRATION_GLOW}
              isPlaying={isNarrationPlaying}
              onPress={onToggleNarration}
            />
          )}
          {hasNarration && hasSoundscape && <View style={styles.divider} />}
          {hasSoundscape && (
            <AudioIconButton
              icon={isSoundscapePlaying ? '\uD83D\uDD0A' : '\uD83C\uDFB5'}
              accentColor={SOUNDSCAPE_COLOR}
              glowColor={SOUNDSCAPE_GLOW}
              isPlaying={isSoundscapePlaying}
              onPress={onToggleSoundscape}
            />
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
  },
  pillContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 8,
    borderRadius: 28,
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  loadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 28,
    overflow: 'hidden',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.1)',
    gap: 8,
  },
  loadingText: {
    fontSize: 13,
    color: 'rgba(255,255,255,0.7)',
    fontFamily: fonts.sans,
  },
  buttonsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  divider: {
    width: StyleSheet.hairlineWidth,
    height: 24,
    backgroundColor: 'rgba(255,255,255,0.12)',
    marginHorizontal: 4,
  },
  iconButtonWrapper: {
    position: 'relative',
    width: 48,
    height: 48,
    justifyContent: 'center',
    alignItems: 'center',
  },
  glowRing: {
    position: 'absolute',
    width: 48,
    height: 48,
    borderRadius: 24,
  },
  iconButton: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(255,255,255,0.06)',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.08)',
  },
  iconText: {
    fontSize: 20,
  },
});
