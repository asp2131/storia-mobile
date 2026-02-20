import { TextElement, TextOverlayConfig } from '@/types';

// Font family to weight variant mapping
export const FONT_MAP: Record<string, Record<number, string>> = {
  Inter: {
    300: 'Inter_300Light',
    400: 'Inter_400Regular',
    500: 'Inter_500Medium',
    600: 'Inter_600SemiBold',
    700: 'Inter_700Bold',
  },
  Lora: {
    300: 'Lora_400Regular', // 300 maps to 400
    400: 'Lora_400Regular',
    500: 'Lora_500Medium',
    600: 'Lora_600SemiBold',
    700: 'Lora_700Bold',
  },
  'Playfair Display': {
    300: 'PlayfairDisplay_400Regular', // 300 maps to 400
    400: 'PlayfairDisplay_400Regular',
    500: 'PlayfairDisplay_500Medium',
    600: 'PlayfairDisplay_600SemiBold',
    700: 'PlayfairDisplay_700Bold',
  },
  'JetBrains Mono': {
    300: 'JetBrainsMono_300Light',
    400: 'JetBrainsMono_400Regular',
    500: 'JetBrainsMono_500Medium',
    600: 'JetBrainsMono_600SemiBold',
    700: 'JetBrainsMono_700Bold',
  },
  Gaegu: {
    300: 'Gaegu_300Light',
    400: 'Gaegu_400Regular',
    500: 'Gaegu_400Regular', // 500 maps to 400
    600: 'Gaegu_700Bold',    // 600 maps to 700
    700: 'Gaegu_700Bold',
  },
};

/**
 * Resolve a font family and weight to the specific font variant name
 */
export function resolveFont(family: string, weight: number): string {
  const familyMap = FONT_MAP[family];
  if (!familyMap) {
    // Fallback to system font weight
    return 'System';
  }

  // Normalize weight to a valid key
  const normalizedWeight = familyMap[weight] ? weight : 400;
  return familyMap[normalizedWeight] ?? familyMap[400] ?? 'System';
}

/**
 * Calculate the rectangle for an image that maintains aspect ratio
 * and fits within the given view dimensions (object-fit: contain behavior)
 */
export function computeContainedImageRect(
  viewWidth: number,
  viewHeight: number,
  imageAspectRatio: number
): { x: number; y: number; width: number; height: number } {
  if (viewWidth <= 0 || viewHeight <= 0 || imageAspectRatio <= 0) {
    return { x: 0, y: 0, width: 0, height: 0 };
  }

  const viewAspectRatio = viewWidth / viewHeight;

  if (imageAspectRatio > viewAspectRatio) {
    // Image is wider than view - constrain by width
    const width = viewWidth;
    const height = width / imageAspectRatio;
    const y = (viewHeight - height) / 2;
    return { x: 0, y, width, height };
  } else {
    // Image is taller than view - constrain by height
    const height = viewHeight;
    const width = height * imageAspectRatio;
    const x = (viewWidth - width) / 2;
    return { x, y: 0, width, height };
  }
}

/**
 * Derive the full text content from all overlay elements
 * Concatenates element texts with a space separator
 */
export function deriveTextContent(overlay: TextOverlayConfig): string {
  if (!overlay || !Array.isArray(overlay.elements)) {
    return '';
  }

  return overlay.elements
    .filter((el): el is TextElement => el && typeof el.text === 'string')
    .map(el => el.text.trim())
    .filter(text => text.length > 0)
    .join(' ');
}

/**
 * Calculate the starting word index for each text element
 * Returns a map of element ID to its starting word position
 */
export function calculateWordStartsByElementId(
  overlay: TextOverlayConfig
): Map<string, number> {
  const wordStarts = new Map<string, number>();

  if (!overlay || !Array.isArray(overlay.elements)) {
    return wordStarts;
  }

  let wordCount = 0;

  for (const element of overlay.elements) {
    if (!element || typeof element.text !== 'string') {
      continue;
    }

    wordStarts.set(element.id, wordCount);

    // Count words in this element's text
    const trimmed = element.text.trim();
    if (trimmed.length > 0) {
      const words = trimmed.split(/\s+/);
      wordCount += words.length;
    }
  }

  return wordStarts;
}
