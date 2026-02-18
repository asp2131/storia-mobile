import React, { useEffect, useCallback } from 'react';
import { View, Text, StyleSheet, Dimensions, Pressable } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withRepeat,
  withSequence,
  withDelay,
  interpolate,
  runOnJS,
  Easing,
} from 'react-native-reanimated';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useThemeColors, fonts } from '@/lib/theme';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const TUTORIAL_KEY = 'storia_has_seen_gesture_tutorial';
const AUTO_DISMISS_DELAY = 4000;

interface GestureTutorialProps {
  onComplete?: () => void;
  visible: boolean;
}

export async function hasSeenGestureTutorial(): Promise<boolean> {
  try {
    const value = await AsyncStorage.getItem(TUTORIAL_KEY);
    return value === 'true';
  } catch {
    return false;
  }
}

export async function markGestureTutorialSeen(): Promise<void> {
  try {
    await AsyncStorage.setItem(TUTORIAL_KEY, 'true');
  } catch {
    // Silently fail
  }
}

export function GestureTutorial({ onComplete, visible }: GestureTutorialProps) {
  const colors = useThemeColors();

  const backdropOpacity = useSharedValue(0);
  const contentOpacity = useSharedValue(0);
  const handTranslateY = useSharedValue(0);
  const handScale = useSharedValue(1);
  const textTranslateY = useSharedValue(20);

  const handleDismiss = useCallback(() => {
    backdropOpacity.value = withTiming(0, { duration: 300 });
    contentOpacity.value = withTiming(0, { duration: 250 }, (finished) => {
      if (finished && onComplete) {
        runOnJS(onComplete)();
      }
    });
  }, [backdropOpacity, contentOpacity, onComplete]);

  useEffect(() => {
    if (visible) {
      backdropOpacity.value = withTiming(1, { duration: 400 });
      contentOpacity.value = withDelay(
        200,
        withTiming(1, { duration: 400 })
      );
      textTranslateY.value = withDelay(
        300,
        withTiming(0, { duration: 400, easing: Easing.out(Easing.back(1.5)) })
      );

      handTranslateY.value = withDelay(
        500,
        withRepeat(
          withSequence(
            withTiming(-60, { duration: 600, easing: Easing.inOut(Easing.quad) }),
            withTiming(0, { duration: 400, easing: Easing.out(Easing.quad) })
          ),
          3,
          true
        )
      );

      handScale.value = withDelay(
        500,
        withRepeat(
          withSequence(
            withTiming(0.95, { duration: 600, easing: Easing.inOut(Easing.quad) }),
            withTiming(1, { duration: 400, easing: Easing.out(Easing.quad) })
          ),
          3,
          true
        )
      );

      const timer = setTimeout(() => {
        handleDismiss();
      }, AUTO_DISMISS_DELAY);

      return () => clearTimeout(timer);
    }
  }, [visible]);

  const backdropStyle = useAnimatedStyle(() => ({
    opacity: backdropOpacity.value,
  }));

  const contentStyle = useAnimatedStyle(() => ({
    opacity: contentOpacity.value,
    transform: [{ translateY: textTranslateY.value }],
  }));

  const handStyle = useAnimatedStyle(() => ({
    transform: [
      { translateY: handTranslateY.value },
      { scale: handScale.value },
    ],
  }));

  const glowStyle = useAnimatedStyle(() => ({
    opacity: interpolate(
      handTranslateY.value,
      [-60, 0],
      [0.6, 0],
      'clamp'
    ),
    transform: [
      { scale: interpolate(handTranslateY.value, [-60, 0], [1.2, 1], 'clamp') },
    ],
  }));

  if (!visible) return null;

  return (
    <Pressable onPress={handleDismiss} style={styles.pressableOverlay}>
      <Animated.View style={[styles.container, backdropStyle]} pointerEvents="box-none">
        <Animated.View
          style={[
            styles.backdrop,
            { backgroundColor: colors.readerBg },
          ]}
        />

        <Animated.View style={[styles.content, contentStyle]} pointerEvents="none">
          <View style={styles.handContainer}>
            <Animated.View
              style={[
                styles.glow,
                glowStyle,
                { backgroundColor: colors.storiaPrimary },
              ]}
            />
            <Animated.View style={[styles.handWrapper, handStyle]}>
              <Text style={styles.handEmoji}>👆</Text>
            </Animated.View>
          </View>

          <Text
            style={[
              styles.instructionText,
              { color: colors.readerText, fontFamily: fonts.sans },
            ]}
          >
            Swipe up to turn the page
          </Text>

          <View style={styles.dismissButton}>
            <Text
              style={[
                styles.dismissText,
                { color: colors.readerTextSecondary, fontFamily: fonts.sans },
              ]}
            >
              Tap anywhere to dismiss
            </Text>
          </View>
        </Animated.View>
      </Animated.View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  pressableOverlay: {
    ...StyleSheet.absoluteFillObject,
    zIndex: 1000,
  },
  container: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: 'center',
    alignItems: 'center',
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    opacity: 0.85,
  },
  content: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 40,
  },
  handContainer: {
    width: 120,
    height: 120,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 24,
  },
  glow: {
    position: 'absolute',
    width: 80,
    height: 80,
    borderRadius: 40,
    opacity: 0,
  },
  handWrapper: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  handEmoji: {
    fontSize: 64,
    transform: [{ rotate: '-45deg' }],
  },
  instructionText: {
    fontSize: 22,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 16,
  },
  dismissButton: {
    paddingVertical: 8,
    paddingHorizontal: 16,
  },
  dismissText: {
    fontSize: 14,
    opacity: 0.7,
  },
});
