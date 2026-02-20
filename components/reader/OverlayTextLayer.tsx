import React, { useMemo } from 'react';
import { View } from 'react-native';
import type { TextOverlayConfig } from '@/types';
import { calculateWordStartsByElementId } from '@/lib/textOverlay';
import { OverlayTextElement } from './OverlayTextElement';

interface OverlayTextLayerProps {
  overlay: TextOverlayConfig;
  imageWidth: number;
  imageHeight: number;
  activeWordIndex?: number;
  pronouncingWordIndex?: number | null;
  isActive: boolean;
  onWordTap?: (word: string, globalIndex: number) => void;
}

export function OverlayTextLayer({
  overlay,
  imageWidth,
  imageHeight,
  activeWordIndex,
  pronouncingWordIndex,
  isActive,
  onWordTap,
}: OverlayTextLayerProps) {
  // Compute global word start indices for each element
  const wordStartsByElementId = useMemo(() => {
    return calculateWordStartsByElementId(overlay);
  }, [overlay]);

  // Return null if dimensions are invalid
  if (imageWidth === 0 || imageHeight === 0) {
    return null;
  }

  return (
    <View
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        width: imageWidth,
        height: imageHeight,
      }}
      pointerEvents="box-none"
    >
      {overlay.elements.map((element, index) => (
        <OverlayTextElement
          key={element.id}
          element={element}
          elementIndex={index}
          imageWidth={imageWidth}
          imageHeight={imageHeight}
          wordStartIndex={wordStartsByElementId.get(element.id) ?? 0}
          activeWordIndex={activeWordIndex}
          pronouncingWordIndex={pronouncingWordIndex}
          isActive={isActive}
          onWordTap={onWordTap}
        />
      ))}
    </View>
  );
}
