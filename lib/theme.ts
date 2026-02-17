import { useColorScheme } from 'react-native';

const lightColors = {
  // Reader
  readerBg: '#ffffff',
  readerText: '#1a1a2e',
  readerTextSecondary: '#6b7280',
  readerCardBg: '#f3f4f6',
  readerProgressBarBg: '#e5e7eb',
  readerProgressBarFill: '#58cc02',
  readerHighlightBg: '#d4edbc',
  readerNavBtnBg: '#1cb0f6',
  readerNavBtnText: '#ffffff',
  readerCloseColor: '#afafaf',

  // Brand
  storiaPrimary: '#6366F1',
  storiaPrimaryHover: '#818CF8',
  storiaPrimaryDark: '#4F46E5',
  storiaAccent: '#F59E0B',
  storiaAccentHover: '#D97706',
  storiaSurface: '#F8FAFC',
  storiaBorder: '#E2E8F0',
  storiaInputBg: '#F1F5F9',
  storiaNavBg: '#FFFFFF',

  // Semantic
  background: '#ffffff',
  text: '#1a1a2e',
  textSecondary: '#6b7280',
  card: '#f3f4f6',
  border: '#E2E8F0',
  error: '#EF4444',
  success: '#58cc02',
};

const darkColors: typeof lightColors = {
  // Reader
  readerBg: '#131f24',
  readerText: '#e2e8f0',
  readerTextSecondary: '#94a3b8',
  readerCardBg: '#1e293b',
  readerProgressBarBg: '#334155',
  readerProgressBarFill: '#58cc02',
  readerHighlightBg: 'rgba(88, 204, 2, 0.25)',
  readerNavBtnBg: '#1cb0f6',
  readerNavBtnText: '#ffffff',
  readerCloseColor: '#64748b',

  // Brand
  storiaPrimary: '#818CF8',
  storiaPrimaryHover: '#A5B4FC',
  storiaPrimaryDark: '#6366F1',
  storiaAccent: '#FBBF24',
  storiaAccentHover: '#F59E0B',
  storiaSurface: '#1E293B',
  storiaBorder: '#334155',
  storiaInputBg: '#1E293B',
  storiaNavBg: '#0F172A',

  // Semantic
  background: '#131f24',
  text: '#e2e8f0',
  textSecondary: '#94a3b8',
  card: '#1e293b',
  border: '#334155',
  error: '#F87171',
  success: '#58cc02',
};

export type ThemeColors = typeof lightColors;

export function useThemeColors(): ThemeColors {
  const scheme = useColorScheme();
  return scheme === 'dark' ? darkColors : lightColors;
}

export const fonts = {
  sans: 'Inter',
  serif: 'Lora',
  display: 'PlayfairDisplay',
} as const;

export { lightColors, darkColors };
