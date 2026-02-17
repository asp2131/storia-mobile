import { useAnimatedStyle } from 'react-native-reanimated';
import { PageRenderer } from '@/components/PageRenderer';
import type { PageData, WordTimestamp } from '@/types';

interface PageLayerProps {
  page: PageData;
  pageIndex: number;
  activeIndex: number;
  narrationTimestamps: WordTimestamp[] | null;
  currentPositionMs: number;
  isNarrationPlaying: boolean;
  usePageAnimatedStyle: (index: number) => ReturnType<typeof useAnimatedStyle>;
}

export function PageLayer({
  page,
  pageIndex,
  activeIndex,
  narrationTimestamps,
  currentPositionMs,
  isNarrationPlaying,
  usePageAnimatedStyle,
}: PageLayerProps) {
  const animatedStyle = usePageAnimatedStyle(pageIndex);

  return (
    <PageRenderer
      page={page}
      activeWordIndex={-1}
      isActive={pageIndex === activeIndex}
      animatedStyle={animatedStyle}
      narrationTimestamps={narrationTimestamps}
      currentPositionMs={currentPositionMs}
      isNarrationPlaying={isNarrationPlaying}
    />
  );
}
