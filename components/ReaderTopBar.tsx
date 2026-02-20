import React from 'react';
import { View, TouchableOpacity, Text, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BlurView } from 'expo-blur';
import Animated, {
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';
import { fonts } from '@/lib/theme';

type Props = {
  progressPercent: number;
  currentPage: number;
  totalPages: number;
  onClose: () => void;
  onSettings: () => void;
  isVisible?: boolean;
};

export const ReaderTopBar = React.memo(function ReaderTopBar({
  progressPercent,
  currentPage,
  totalPages,
  onClose,
  onSettings,
  isVisible = true,
}: Props) {
  const insets = useSafeAreaInsets();

  const progressStyle = useAnimatedStyle(() => ({
    width: `${withTiming(progressPercent, { duration: 400 })}%` as `${number}%`,
  }));

  const containerStyle = useAnimatedStyle(() => ({
    opacity: withTiming(isVisible ? 1 : 0, { duration: 300 }),
    transform: [
      { translateY: withTiming(isVisible ? 0 : -20, { duration: 300 }) },
    ],
  }));

  return (
    <Animated.View style={containerStyle} pointerEvents={isVisible ? 'auto' : 'none'}>
      <BlurView
        intensity={40}
        tint="dark"
        style={[styles.container, { paddingTop: insets.top + 2 }]}
      >
        {/* Close button - left */}
        <TouchableOpacity onPress={onClose} style={styles.closeButton} hitSlop={12}>
          <View style={styles.closeIconContainer}>
            <Text style={styles.closeIcon}>{'\u2715'}</Text>
          </View>
        </TouchableOpacity>

        {/* Center section: progress bar */}
        <View style={styles.centerSection}>
          <View style={styles.progressTrack}>
            <Animated.View style={[styles.progressFill, progressStyle]}>
              <View style={styles.progressGlow} />
            </Animated.View>
          </View>
        </View>

        {/* Page counter - right */}
        <Text style={styles.pageCounter}>
          {currentPage}
          <Text style={styles.pageCounterSeparator}> / </Text>
          {totalPages}
        </Text>
      </BlurView>
    </Animated.View>
  );
});

export const TOP_BAR_HEIGHT = 48;

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 50,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingBottom: 10,
    overflow: 'hidden',
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: 'rgba(255,255,255,0.06)',
  },
  closeButton: {
    width: 36,
    height: 36,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  closeIconContainer: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: 'rgba(255,255,255,0.08)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  closeIcon: {
    fontSize: 12,
    fontWeight: '600',
    color: 'rgba(255,255,255,0.7)',
  },
  centerSection: {
    flex: 1,
    justifyContent: 'center',
  },
  progressTrack: {
    height: 3,
    borderRadius: 1.5,
    backgroundColor: 'rgba(255,255,255,0.08)',
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 1.5,
    backgroundColor: '#F59E0B',
    position: 'relative',
  },
  progressGlow: {
    position: 'absolute',
    right: 0,
    top: -1,
    bottom: -1,
    width: 12,
    borderRadius: 6,
    backgroundColor: 'rgba(245, 158, 11, 0.5)',
  },
  pageCounter: {
    fontSize: 12,
    fontWeight: '500',
    fontFamily: fonts.sans,
    fontVariant: ['tabular-nums'],
    color: 'rgba(255,255,255,0.5)',
    marginLeft: 12,
    letterSpacing: 0.5,
  },
  pageCounterSeparator: {
    color: 'rgba(255,255,255,0.25)',
    fontWeight: '300',
  },
});
