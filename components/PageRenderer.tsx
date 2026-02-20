import React, { useState, useCallback, useMemo } from 'react';
import { View, StyleSheet, Dimensions, type LayoutChangeEvent } from 'react-native';
import { Image, type ImageLoadEventData } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import Animated, { type AnimatedStyle } from 'react-native-reanimated';
import { WordHighlighter } from './WordHighlighter';
import { OverlayTextLayer } from './reader/OverlayTextLayer';
import type { PageData, WordTimestamp } from '@/types';
import { useThemeColors, fonts } from '@/lib/theme';
import { computeContainedImageRect } from '@/lib/textOverlay';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

type Props = {
  page: PageData;
  activeWordIndex: number;
  isActive: boolean;
  animatedStyle: AnimatedStyle;
  narrationTimestamps: WordTimestamp[] | null;
  currentPositionMs: number;
  isNarrationPlaying: boolean;
  onWordTap?: (word: string, globalIndex: number) => void;
  pronouncingWordIndex?: number;
};

export const PageRenderer = React.memo(function PageRenderer({
  page,
  isActive,
  animatedStyle,
  narrationTimestamps,
  currentPositionMs,
  isNarrationPlaying,
  onWordTap,
  pronouncingWordIndex,
}: Props) {
  const colors = useThemeColors();

  // Image measurement state
  const [imageDimensions, setImageDimensions] = useState({ width: 0, height: 0 });
  const [sourceImageDimensions, setSourceImageDimensions] = useState<{ width: number; height: number } | null>(null);

  // Handlers for image measurement
  const onImageLayout = useCallback((event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    setImageDimensions({ width, height });
  }, []);

  const onImageLoad = useCallback((event: ImageLoadEventData) => {
    setSourceImageDimensions({
      width: event.source.width,
      height: event.source.height,
    });
  }, []);

  // Determine display mode
  const hasOverlay = (page.overlay?.elements?.length ?? 0) > 0;
  const hasComposited = !!(page as any).compositedImageUrl;
  const hasFallback = !!page.textContent && !!page.imageUrl;

  // Compute contained image rect when using overlay mode
  const containedRect = useMemo(() => {
    if (!hasOverlay || !sourceImageDimensions) return null;
    return computeContainedImageRect(
      imageDimensions.width,
      imageDimensions.height,
      sourceImageDimensions.width / sourceImageDimensions.height
    );
  }, [hasOverlay, imageDimensions, sourceImageDimensions]);

  // Calculate active word index from narration timestamps
  const computedActiveWordIndex = useMemo(() => {
    if (!isNarrationPlaying || !narrationTimestamps || narrationTimestamps.length === 0) return -1;

    const currentTime = currentPositionMs / 1000;
    let foundIndex = -1;

    for (let i = 0; i < narrationTimestamps.length; i++) {
      const wordData = narrationTimestamps[i];
      const nextWord = narrationTimestamps[i + 1];

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
  }, [currentPositionMs, narrationTimestamps, isNarrationPlaying]);

  // Determine content fit based on mode
  const contentFit: 'cover' | 'contain' = hasOverlay ? 'contain' : 'cover';

  return (
    <Animated.View style={[styles.page, animatedStyle]}>
      {/* View wrapper with onLayout for measurement */}
      <View style={styles.imageContainer} onLayout={onImageLayout}>
        {/* Full-bleed illustration */}
        {page.imageUrl ? (
          <Image
            source={{ uri: page.imageUrl }}
            style={styles.fullBleedImage}
            contentFit={contentFit}
            transition={isActive ? 300 : 0}
            onLoad={onImageLoad}
          />
        ) : (
          <View style={[styles.fullBleedImage, { backgroundColor: colors.readerCardBg }]} />
        )}

        {/* DYNAMIC OVERLAY mode: Render OverlayTextLayer positioned at containedRect */}
        {hasOverlay && containedRect && page.overlay && (
          <View
            style={[
              styles.overlayLayer,
              {
                left: containedRect.x,
                top: containedRect.y,
                width: containedRect.width,
                height: containedRect.height,
              },
            ]}
          >
            <OverlayTextLayer
              overlay={page.overlay}
              imageWidth={containedRect.width}
              imageHeight={containedRect.height}
              activeWordIndex={computedActiveWordIndex}
              pronouncingWordIndex={pronouncingWordIndex}
              isActive={isActive}
              onWordTap={onWordTap}
            />
          </View>
        )}

        {/* COMPOSITED mode: No additional overlay components needed */}
        {/* Image is already rendered above with contentFit="cover" */}

        {/* FALLBACK mode: Gradient scrims + WordHighlighter at bottom */}
        {!hasOverlay && !hasComposited && hasFallback && page.textContent && (
          <>
            {/* Gradient scrim for text readability */}
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

            {/* Overlaid text at bottom */}
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
          </>
        )}

        {/* IMAGE ONLY mode: Just image, no text - already rendered above */}
      </View>
    </Animated.View>
  );
});

const styles = StyleSheet.create({
  page: {
    ...StyleSheet.absoluteFillObject,
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
  },
  imageContainer: {
    ...StyleSheet.absoluteFillObject,
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
  },
  fullBleedImage: {
    ...StyleSheet.absoluteFillObject,
    width: SCREEN_WIDTH,
    height: SCREEN_HEIGHT,
  },
  overlayLayer: {
    position: 'absolute',
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
