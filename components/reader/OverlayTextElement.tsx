import React, { useEffect } from 'react';
import { Text, View, StyleSheet, Pressable, type TextStyle, type ViewStyle } from 'react-native';
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withTiming,
  withDelay,
  Easing,
} from 'react-native-reanimated';
import type { TextElement } from '@/types';
import { resolveFont } from '@/lib/textOverlay';

interface OverlayTextElementProps {
  element: TextElement;
  elementIndex: number;
  imageWidth: number;
  imageHeight: number;
  wordStartIndex: number;
  activeWordIndex?: number;
  pronouncingWordIndex?: number | null;
  isActive: boolean;
  onWordTap?: (word: string, globalIndex: number) => void;
}

export function OverlayTextElement({
  element,
  elementIndex,
  imageWidth,
  imageHeight,
  wordStartIndex,
  activeWordIndex,
  pronouncingWordIndex,
  isActive,
  onWordTap,
}: OverlayTextElementProps) {
  // Animation value
  const progress = useSharedValue(0);

  // Stagger entrance animation
  useEffect(() => {
    if (isActive) {
      const delay = 180 + elementIndex * 40;
      progress.value = withDelay(
        delay,
        withTiming(1, {
          duration: 350,
          easing: Easing.out(Easing.ease),
        })
      );
    } else {
      // Reset immediately when inactive
      progress.value = 0;
    }
  }, [isActive, elementIndex, progress]);

  // Animated style for container
  const animatedStyle = useAnimatedStyle(() => ({
    opacity: progress.value,
    transform: [{ translateY: (1 - progress.value) * 16 }],
  }));

  // Convert percentage to pixels
  const x = (element.x / 100) * imageWidth;
  const y = (element.y / 100) * imageHeight;
  const width = (element.width / 100) * imageWidth;

  // Resolve font family (weight encoded in name)
  const fontFamily = resolveFont(element.fontFamily, element.fontWeight);

  // Calculate font size based on image height (assuming 100% = full image height)
  const fontSize = (element.fontSize / 100) * imageHeight;

  // Build text style
  const textStyle: TextStyle = {
    fontFamily,
    fontSize,
    color: element.color,
    textAlign: element.textAlign,
    lineHeight: fontSize * 1.3,
  };

  // Shadow style
  const shadowStyle: TextStyle = element.shadow
    ? {
        textShadowColor: element.shadow.color,
        textShadowOffset: { width: element.shadow.x, height: element.shadow.y },
        textShadowRadius: element.shadow.blur,
      }
    : {};

  // Container styles
  const containerStyle: ViewStyle = {
    position: 'absolute',
    left: x,
    top: y,
    width,
    transform: element.rotation !== 0 ? [{ rotate: `${element.rotation}deg` }] : undefined,
  };

  // Background container style
  const backgroundStyle: ViewStyle = element.background
    ? {
        backgroundColor: element.background.color,
        padding: element.background.padding || 0,
        borderRadius: element.background.borderRadius || 0,
      }
    : {};

  // Split text into tokens (preserving whitespace)
  const tokens = element.text.split(/(\s+)/);

  // Check if a word is highlighted
  const isWordHighlighted = (globalIndex: number): boolean => {
    if (activeWordIndex !== undefined && globalIndex === activeWordIndex) {
      return true;
    }
    if (pronouncingWordIndex !== null && pronouncingWordIndex !== undefined && globalIndex === pronouncingWordIndex) {
      return true;
    }
    return false;
  };

  // Word index tracker
  let currentWordIndex = wordStartIndex;

  return (
    <Animated.View style={[containerStyle, animatedStyle]} pointerEvents="box-none">
      <View style={backgroundStyle}>
        <Text style={[textStyle, shadowStyle]}>
          {tokens.map((token, tokenIndex) => {
            // Check if token is whitespace
            if (/^\s+$/.test(token)) {
              return token;
            }

            // It's a word
            const globalIndex = currentWordIndex;
            const isHighlighted = isWordHighlighted(globalIndex);
            currentWordIndex++;

            const wordStyle: TextStyle = isHighlighted
              ? {
                  backgroundColor: 'rgba(212, 237, 188, 0.8)',
                  borderRadius: 4,
                  paddingHorizontal: 2,
                }
              : {};

            if (onWordTap) {
              return (
                <Pressable
                  key={tokenIndex}
                  onPress={() => onWordTap(token, globalIndex)}
                  style={styles.pressableWord}
                >
                  <Text style={[textStyle, shadowStyle, wordStyle]}>{token}</Text>
                </Pressable>
              );
            }

            return (
              <Text key={tokenIndex} style={[textStyle, shadowStyle, wordStyle]}>
                {token}
              </Text>
            );
          })}
        </Text>
      </View>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  pressableWord: {
    display: 'flex',
  },
});
