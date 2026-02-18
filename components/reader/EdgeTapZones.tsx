import React, { useCallback } from 'react';
import { View, StyleSheet, Dimensions, TouchableOpacity } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';

const { width: SCREEN_WIDTH } = Dimensions.get('window');
const EDGE_ZONE_WIDTH = 50;

interface EdgeTapZonesProps {
  onPrevious: () => void;
  onNext: () => void;
  isVisible: boolean;
}

export function EdgeTapZones({ onPrevious, onNext, isVisible }: EdgeTapZonesProps) {
  const leftOpacity = useSharedValue(0);
  const rightOpacity = useSharedValue(0);

  const handleLeftPressIn = useCallback(() => {
    leftOpacity.value = withTiming(0.3, { duration: 150 });
  }, [leftOpacity]);

  const handleLeftPressOut = useCallback(() => {
    leftOpacity.value = withTiming(0, { duration: 200 });
  }, [leftOpacity]);

  const handleRightPressIn = useCallback(() => {
    rightOpacity.value = withTiming(0.3, { duration: 150 });
  }, [rightOpacity]);

  const handleRightPressOut = useCallback(() => {
    rightOpacity.value = withTiming(0, { duration: 200 });
  }, [rightOpacity]);

  const leftAnimatedStyle = useAnimatedStyle(() => ({
    opacity: isVisible ? leftOpacity.value : 0,
  }));

  const rightAnimatedStyle = useAnimatedStyle(() => ({
    opacity: isVisible ? rightOpacity.value : 0,
  }));

  return (
    <>
      {/* Left Edge Zone */}
      <View style={styles.leftZone} pointerEvents={isVisible ? 'auto' : 'none'}>
        <TouchableOpacity
          style={styles.touchable}
          onPress={onPrevious}
          onPressIn={handleLeftPressIn}
          onPressOut={handleLeftPressOut}
          activeOpacity={1}
        >
          <Animated.View style={[styles.gradientIndicator, styles.leftGradient, leftAnimatedStyle]} />
        </TouchableOpacity>
      </View>

      {/* Right Edge Zone */}
      <View style={styles.rightZone} pointerEvents={isVisible ? 'auto' : 'none'}>
        <TouchableOpacity
          style={styles.touchable}
          onPress={onNext}
          onPressIn={handleRightPressIn}
          onPressOut={handleRightPressOut}
          activeOpacity={1}
        >
          <Animated.View style={[styles.gradientIndicator, styles.rightGradient, rightAnimatedStyle]} />
        </TouchableOpacity>
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  leftZone: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: EDGE_ZONE_WIDTH,
    zIndex: 10,
  },
  rightZone: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: EDGE_ZONE_WIDTH,
    zIndex: 10,
  },
  touchable: {
    flex: 1,
  },
  gradientIndicator: {
    width: '100%',
    height: '100%',
  },
  leftGradient: {
    backgroundColor: 'rgba(255,255,255,0.15)',
  },
  rightGradient: {
    backgroundColor: 'rgba(255,255,255,0.15)',
  },
});
