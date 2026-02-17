import React from 'react';
import { View, TouchableOpacity, Text, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { BlurView } from 'expo-blur';
import Animated, {
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';
import { useThemeColors, fonts } from '@/lib/theme';

type Props = {
  progressPercent: number;
  currentPage: number;
  totalPages: number;
  onClose: () => void;
  onSettings: () => void;
};

export function ReaderTopBar({
  progressPercent,
  currentPage,
  totalPages,
  onClose,
  onSettings,
}: Props) {
  const insets = useSafeAreaInsets();
  const colors = useThemeColors();

  const progressStyle = useAnimatedStyle(() => ({
    width: `${withTiming(progressPercent, { duration: 300 })}%` as `${number}%`,
  }));

  return (
    <BlurView
      intensity={60}
      tint="systemChromeMaterialDark"
      style={[styles.container, { paddingTop: insets.top + 4 }]}
    >
      <TouchableOpacity onPress={onClose} style={styles.closeButton} hitSlop={8}>
        <Text style={[styles.closeIcon, { color: colors.readerCloseColor }]}>
          {'\u2715'}
        </Text>
      </TouchableOpacity>

      <View style={[styles.progressTrack, { backgroundColor: colors.readerProgressBarBg }]}>
        <Animated.View
          style={[
            styles.progressFill,
            { backgroundColor: colors.readerProgressBarFill },
            progressStyle,
          ]}
        />
      </View>

      <Text style={[styles.pageCounter, { color: colors.readerTextSecondary }]}>
        {currentPage}/{totalPages}
      </Text>

      <TouchableOpacity onPress={onSettings} style={styles.settingsButton} hitSlop={8}>
        <Text style={[styles.settingsIcon, { color: colors.readerCloseColor }]}>
          {'\u2699'}
        </Text>
      </TouchableOpacity>
    </BlurView>
  );
}

export const TOP_BAR_HEIGHT = 56;

const styles = StyleSheet.create({
  container: {
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
    overflow: 'hidden',
  },
  closeButton: {
    padding: 4,
  },
  closeIcon: {
    fontSize: 20,
    fontWeight: '600',
  },
  progressTrack: {
    flex: 1,
    height: 12,
    borderRadius: 6,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    borderRadius: 6,
  },
  pageCounter: {
    fontSize: 12,
    fontWeight: '500',
    fontFamily: 'Inter',
    fontVariant: ['tabular-nums'],
  },
  settingsButton: {
    padding: 4,
  },
  settingsIcon: {
    fontSize: 20,
  },
});
