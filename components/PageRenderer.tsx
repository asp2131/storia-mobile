import React from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { type AnimatedStyle } from 'react-native-reanimated';
import { WordHighlighter } from './WordHighlighter';
import type { PageData, WordTimestamp } from '@/types';
import { useThemeColors, fonts } from '@/lib/theme';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

type Props = {
  page: PageData;
  activeWordIndex: number;
  isActive: boolean;
  animatedStyle: AnimatedStyle;
  narrationTimestamps: WordTimestamp[] | null;
  currentPositionMs: number;
  isNarrationPlaying: boolean;
  onWordTap?: (index: number) => void;
};

export function PageRenderer({
  page,
  isActive,
  animatedStyle,
  narrationTimestamps,
  currentPositionMs,
  isNarrationPlaying,
}: Props) {
  const colors = useThemeColors();

  return (
    <Animated.View style={[styles.page, animatedStyle]}>
      {/* Full-bleed illustration */}
      {page.imageUrl ? (
        <Image
          source={{ uri: page.imageUrl }}
          style={styles.fullBleedImage}
          contentFit="cover"
          transition={isActive ? 300 : 0}
        />
      ) : (
        <View style={[styles.fullBleedImage, { backgroundColor: colors.readerCardBg }]} />
      )}

      {/* Gradient scrim for text readability */}
      {page.textContent && (
        <>
          <LinearGradient
            colors={['transparent', 'rgba(0,0,0,0.5)', 'rgba(0,0,0,0.85)']}
            locations={[0, 0.3, 1]}
            style={styles.gradientScrim}
          />
          <LinearGradient
            colors={['transparent', 'rgba(0,0,0,0.3)']}
            locations={[0.5, 1]}
            style={[styles.gradientScrim, { height: SCREEN_HEIGHT * 0.25 }]}
          />
        </>
      )}

      {/* Overlaid text */}
      {page.textContent && (
        <View style={styles.textOverlay}>
          <WordHighlighter
            text={page.textContent}
            timestamps={narrationTimestamps}
            currentPositionMs={currentPositionMs}
            isPlaying={isActive && isNarrationPlaying}
            isActive={isActive}
            overlayMode
          />
        </View>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  page: {
    ...StyleSheet.absoluteFillObject,
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
  },
  fullBleedImage: {
    ...StyleSheet.absoluteFillObject,
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
  },
  gradientScrim: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: SCREEN_HEIGHT * 0.55,
  },
  textOverlay: {
    position: 'absolute',
    bottom: 140,
    left: 28,
    right: 28,
  },
});
