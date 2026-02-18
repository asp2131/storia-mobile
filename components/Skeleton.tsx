import React, { useEffect } from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
  interpolate,
} from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useThemeColors } from '@/lib/theme';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
const SHIMMER_DURATION = 1500;

interface SkeletonProps {
  width?: number | string;
  height?: number;
  borderRadius?: number;
  style?: any;
}

function ShimmerGradient({ children }: { children: React.ReactNode }) {
  const translateX = useSharedValue(-SCREEN_WIDTH);

  useEffect(() => {
    translateX.value = withRepeat(
      withTiming(SCREEN_WIDTH, { duration: SHIMMER_DURATION }),
      -1,
      false
    );
  }, [translateX]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: translateX.value }],
  }));

  return (
    <View style={styles.shimmerContainer}>
      <View style={styles.shimmerMask}>
        {children}
      </View>
      <Animated.View style={[styles.shimmerGradient, animatedStyle]}>
        <LinearGradient
          colors={[
            'rgba(255,255,255,0)',
            'rgba(255,255,255,0.5)',
            'rgba(255,255,255,0)',
          ]}
          start={{ x: 0, y: 0.5 }}
          end={{ x: 1, y: 0.5 }}
          style={styles.gradient}
        />
      </Animated.View>
    </View>
  );
}

export function Skeleton({
  width = '100%',
  height = 20,
  borderRadius = 8,
  style,
}: SkeletonProps) {
  const colors = useThemeColors();

  return (
    <ShimmerGradient>
      <View
        style={[
          styles.skeleton,
          {
            width,
            height,
            borderRadius,
            backgroundColor: colors.readerCardBg,
          },
          style,
        ]}
      />
    </ShimmerGradient>
  );
}

export function ReaderSkeleton() {
  const colors = useThemeColors();
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.container, { backgroundColor: colors.readerBg }]}>
      {/* Top Bar Skeleton */}
      <View style={[styles.topBar, { paddingTop: insets.top + 4 }]}>
        <Skeleton width={44} height={44} borderRadius={22} />
        <View style={styles.progressContainer}>
          <Skeleton height={12} borderRadius={6} />
        </View>
        <Skeleton width={44} height={44} borderRadius={22} />
      </View>

      {/* Illustration Placeholder */}
      <View style={styles.illustrationContainer}>
        <ShimmerGradient>
          <View
            style={[
              styles.illustration,
              { backgroundColor: colors.readerCardBg },
            ]}
          />
        </ShimmerGradient>
      </View>

      {/* Gradient Scrim Effect */}
      <LinearGradient
        colors={['transparent', 'rgba(0,0,0,0.3)', 'rgba(0,0,0,0.6)']}
        locations={[0, 0.4, 1]}
        style={styles.gradientScrim}
      />

      {/* Text Overlay Skeleton */}
      <View style={styles.textOverlay}>
        <Skeleton height={24} borderRadius={12} style={styles.textLine} />
        <Skeleton height={24} borderRadius={12} style={styles.textLine} />
        <Skeleton width="80%" height={24} borderRadius={12} style={styles.textLine} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  topBar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 50,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 12,
    gap: 10,
  },
  progressContainer: {
    flex: 1,
  },
  illustrationContainer: {
    flex: 1,
    paddingTop: 80,
  },
  illustration: {
    flex: 1,
    marginHorizontal: 0,
  },
  gradientScrim: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: SCREEN_HEIGHT * 0.45,
  },
  textOverlay: {
    position: 'absolute',
    bottom: 140,
    left: 28,
    right: 28,
    gap: 12,
  },
  textLine: {
    opacity: 0.6,
  },
  shimmerContainer: {
    position: 'relative',
    overflow: 'hidden',
  },
  shimmerMask: {
    overflow: 'hidden',
  },
  shimmerGradient: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    width: SCREEN_WIDTH * 2,
  },
  gradient: {
    flex: 1,
    width: SCREEN_WIDTH,
  },
  skeleton: {
    overflow: 'hidden',
  },
});
