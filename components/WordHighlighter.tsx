import React, { useMemo, useEffect } from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withDelay,
} from 'react-native-reanimated';
import type { WordTimestamp } from '@/types';
import { useThemeColors, fonts } from '@/lib/theme';

type Props = {
  text: string;
  timestamps: WordTimestamp[] | null;
  currentPositionMs: number;
  isPlaying: boolean;
  isActive?: boolean;
  overlayMode?: boolean;
};

function StaggerWord({
  word,
  index,
  isHighlighted,
  highlightBg,
  textColor,
  isActive,
  overlayMode,
}: {
  word: string;
  index: number;
  isHighlighted: boolean;
  highlightBg: string;
  textColor: string;
  isActive: boolean;
  overlayMode?: boolean;
}) {
  const progress = useSharedValue(0);

  useEffect(() => {
    if (isActive) {
      progress.value = 0;
      progress.value = withDelay(
        index * 40,
        withTiming(1, { duration: 300 })
      );
    } else {
      progress.value = 0;
    }
  }, [isActive, index, progress]);

  const animStyle = useAnimatedStyle(() => ({
    opacity: progress.value,
    transform: [{ translateY: (1 - progress.value) * 12 }],
  }));

  return (
    <Animated.Text
      style={[
        overlayMode ? styles.overlayWord : styles.word,
        { color: textColor },
        animStyle,
        isHighlighted && { backgroundColor: highlightBg },
      ]}
    >
      {word}{' '}
    </Animated.Text>
  );
}

export function WordHighlighter({
  text,
  timestamps,
  currentPositionMs,
  isPlaying,
  isActive = true,
  overlayMode = false,
}: Props) {
  const colors = useThemeColors();

  const activeWordIndex = useMemo(() => {
    if (!isPlaying || !timestamps || timestamps.length === 0) return -1;

    const currentTime = currentPositionMs / 1000;
    let foundIndex = -1;

    for (let i = 0; i < timestamps.length; i++) {
      const wordData = timestamps[i];
      const nextWord = timestamps[i + 1];

      if (currentTime >= wordData.start && currentTime <= wordData.end) {
        foundIndex = i;
        break;
      }
      if (nextWord && currentTime > wordData.end && currentTime < nextWord.start) {
        foundIndex = i;
        break;
      }
      if (!nextWord && currentTime >= wordData.start) {
        foundIndex = i;
        break;
      }
      if (currentTime > wordData.end) {
        foundIndex = i;
      }
    }

    return foundIndex;
  }, [currentPositionMs, timestamps, isPlaying]);

  const textColor = overlayMode ? '#ffffff' : colors.readerText;

  if (!timestamps || timestamps.length === 0) {
    // Split plain text into words for stagger animation
    const words = text.split(/\s+/);
    return (
      <Animated.Text style={[overlayMode ? styles.overlayText : styles.text, { fontFamily: fonts.serif }]}>
        {words.map((word, i) => (
          <StaggerWord
            key={i}
            word={word}
            index={i}
            isHighlighted={false}
            highlightBg={colors.readerHighlightBg}
            textColor={textColor}
            isActive={isActive}
            overlayMode={overlayMode}
          />
        ))}
      </Animated.Text>
    );
  }

  return (
    <Animated.Text style={[overlayMode ? styles.overlayText : styles.text, { fontFamily: fonts.serif }]}>
      {timestamps.map((wordData, index) => (
        <StaggerWord
          key={index}
          word={wordData.word}
          index={index}
          isHighlighted={index === activeWordIndex && isPlaying}
          highlightBg={colors.readerHighlightBg}
          textColor={textColor}
          isActive={isActive}
          overlayMode={overlayMode}
        />
      ))}
    </Animated.Text>
  );
}

const styles = StyleSheet.create({
  text: {
    fontSize: 24,
    fontWeight: '700',
    lineHeight: 38,
    textAlign: 'center',
  },
  overlayText: {
    fontSize: 20,
    fontWeight: '700',
    lineHeight: 32,
    textAlign: 'left',
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },
  word: {
    fontSize: 24,
    fontWeight: '700',
    lineHeight: 38,
  },
  overlayWord: {
    fontSize: 20,
    fontWeight: '700',
    lineHeight: 32,
    textShadowColor: 'rgba(0,0,0,0.5)',
    textShadowOffset: { width: 0, height: 1 },
    textShadowRadius: 4,
  },
  highlightedWord: {
    fontWeight: '800',
    borderRadius: 4,
    paddingHorizontal: 2,
  },
});
