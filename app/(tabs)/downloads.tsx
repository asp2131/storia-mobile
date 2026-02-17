import { View, Text, StyleSheet } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useThemeColors, fonts } from '@/lib/theme';

export default function DownloadsScreen() {
  const insets = useSafeAreaInsets();
  const colors = useThemeColors();

  return (
    <View style={[styles.container, { backgroundColor: colors.background, paddingTop: insets.top }]}>
      <Text style={[styles.title, { color: colors.text, fontFamily: fonts.sans }]}>
        Downloads
      </Text>
      <View style={styles.emptyState}>
        <Text style={{ fontSize: 48 }}>{'\u{1F4E5}'}</Text>
        <Text style={[styles.emptyTitle, { color: colors.text, fontFamily: fonts.sans }]}>
          No downloads yet
        </Text>
        <Text style={[styles.emptySubtitle, { color: colors.textSecondary, fontFamily: fonts.sans }]}>
          Long-press a book in the library to download it for offline reading
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  title: {
    fontSize: 28,
    fontWeight: '700',
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 8,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 40,
    paddingBottom: 100,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '600',
    marginTop: 16,
  },
  emptySubtitle: {
    fontSize: 14,
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 20,
  },
});
