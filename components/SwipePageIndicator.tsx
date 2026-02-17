import React, { useEffect } from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  withSequence,
  Easing,
} from 'react-native-reanimated';
import { fonts } from '@/lib/theme';

type Props = {
  visible: boolean;
};

export function SwipePageIndicator({ visible }: Props) {
  const opacity = useSharedValue(visible ? 0.7 : 0);
  const bounceY = useSharedValue(0);

  useEffect(() => {
    opacity.value = withTiming(visible ? 0.7 : 0, { duration: 400 });
  }, [visible, opacity]);

  useEffect(() => {
    bounceY.value = withRepeat(
      withSequence(
        withTiming(6, { duration: 600, easing: Easing.inOut(Easing.ease) }),
        withTiming(0, { duration: 600, easing: Easing.inOut(Easing.ease) })
      ),
      -1,
      true
    );
  }, [bounceY]);

  const containerStyle = useAnimatedStyle(() => ({
    opacity: opacity.value,
  }));

  const chevronStyle = useAnimatedStyle(() => ({
    transform: [{ translateY: bounceY.value }],
  }));

  return (
    <Animated.View style={[styles.container, containerStyle]} pointerEvents="none">
      <Animated.Text style={styles.label}>Swipe up for next page</Animated.Text>
      <Animated.Text style={[styles.chevron, chevronStyle]}>{'\u2303'}</Animated.Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 80,
    left: 0,
    right: 0,
    alignItems: 'center',
    gap: 4,
  },
  label: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 11,
    fontFamily: fonts.sans,
    fontWeight: '500',
    letterSpacing: 1,
    textTransform: 'uppercase',
  },
  chevron: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 24,
    fontWeight: '300',
    marginTop: -6,
  },
});
