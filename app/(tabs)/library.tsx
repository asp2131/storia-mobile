import { useState, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  ActivityIndicator,
  StyleSheet,
  Dimensions,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Image } from 'expo-image';
import { useLibraryBooks } from '@/hooks/useBookData';
import { useThemeColors, fonts } from '@/lib/theme';
import { useNetworkStatus } from '@/hooks/useNetworkStatus';
import type { LibraryBook } from '@/types';

const GENRES = [
  'All',
  'Fantasy',
  'Science Fiction',
  'Mystery',
  'Romance',
  'Horror',
  'Non-Fiction',
  'Adventure',
  'Historical Fiction',
];

const SCREEN_WIDTH = Dimensions.get('window').width;
const CARD_GAP = 12;
const CARD_PADDING = 16;
const NUM_COLUMNS = 2;
const CARD_WIDTH = (SCREEN_WIDTH - CARD_PADDING * 2 - CARD_GAP * (NUM_COLUMNS - 1)) / NUM_COLUMNS;

export default function LibraryScreen() {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const colors = useThemeColors();
  const { isOffline } = useNetworkStatus();

  const [search, setSearch] = useState('');
  const [genre, setGenre] = useState('');
  const [sort] = useState('recent');

  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
    isRefetching,
    refetch,
  } = useLibraryBooks({
    search,
    genre,
    sort,
    userId: undefined,
  });

  const allBooks = useMemo(
    () => data?.pages.flatMap((page) => page.books) ?? [],
    [data]
  );

  const continueReading = useMemo(
    () =>
      allBooks
        .filter((b) => b.currentPage && b.currentPage > 0 && b.progressPercent && b.progressPercent < 100)
        .sort((a, b) => new Date(b.lastReadAt ?? 0).getTime() - new Date(a.lastReadAt ?? 0).getTime())
        .slice(0, 6),
    [allBooks]
  );

  const handleBookPress = useCallback(
    (bookId: string) => {
      router.push(`/reader/${bookId}`);
    },
    [router]
  );

  const renderBookCard = useCallback(
    ({ item }: { item: LibraryBook }) => (
      <TouchableOpacity
        style={[styles.card, { width: CARD_WIDTH, backgroundColor: colors.card }]}
        onPress={() => handleBookPress(item.id)}
        activeOpacity={0.7}
      >
        <Image
          source={{ uri: item.coverUrl || undefined }}
          style={styles.coverImage}
          contentFit="cover"
          placeholder={{ blurhash: 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH' }}
          transition={200}
        />
        {item.hasSoundscape && (
          <View style={[styles.badge, { backgroundColor: colors.storiaPrimary }]}>
            <Text style={styles.badgeText}>{'\u{1F3B5}'}</Text>
          </View>
        )}
        {item.progressPercent != null && item.progressPercent > 0 && (
          <View style={[styles.progressBar, { backgroundColor: colors.readerProgressBarBg }]}>
            <View
              style={[
                styles.progressFill,
                {
                  backgroundColor: colors.readerProgressBarFill,
                  width: `${item.progressPercent}%`,
                },
              ]}
            />
          </View>
        )}
        <Text
          style={[styles.bookTitle, { color: colors.text, fontFamily: fonts.serif }]}
          numberOfLines={2}
        >
          {item.title}
        </Text>
        <Text
          style={[styles.bookAuthor, { color: colors.textSecondary, fontFamily: fonts.sans }]}
          numberOfLines={1}
        >
          {item.author || 'Unknown'}
        </Text>
      </TouchableOpacity>
    ),
    [colors, handleBookPress]
  );

  const renderContinueCard = useCallback(
    ({ item }: { item: LibraryBook }) => (
      <TouchableOpacity
        style={[styles.continueCard, { backgroundColor: colors.card }]}
        onPress={() => handleBookPress(item.id)}
        activeOpacity={0.7}
      >
        <Image
          source={{ uri: item.coverUrl || undefined }}
          style={styles.continueCover}
          contentFit="cover"
          transition={200}
        />
        <View style={styles.continueInfo}>
          <Text
            style={[styles.continueTitle, { color: colors.text, fontFamily: fonts.serif }]}
            numberOfLines={1}
          >
            {item.title}
          </Text>
          <View style={[styles.continueProgressBar, { backgroundColor: colors.readerProgressBarBg }]}>
            <View
              style={[
                styles.continueProgressFill,
                {
                  backgroundColor: colors.readerProgressBarFill,
                  width: `${item.progressPercent ?? 0}%`,
                },
              ]}
            />
          </View>
          <Text style={[styles.continuePercent, { color: colors.textSecondary, fontFamily: fonts.sans }]}>
            {item.progressPercent ?? 0}%
          </Text>
        </View>
      </TouchableOpacity>
    ),
    [colors, handleBookPress]
  );

  const ListHeader = useMemo(
    () => (
      <View>
        {/* Header */}
        <View style={[styles.header, { paddingTop: insets.top + 8 }]}>
          <Text style={[styles.headerTitle, { color: colors.storiaPrimary, fontFamily: fonts.display }]}>
            Storia
          </Text>
        </View>

        {/* Offline banner */}
        {isOffline && (
          <View style={[styles.offlineBanner, { backgroundColor: colors.storiaAccent }]}>
            <Text style={[styles.offlineText, { fontFamily: fonts.sans }]}>
              You're offline. Showing cached data.
            </Text>
          </View>
        )}

        {/* Search */}
        <View style={styles.searchSection}>
          <TextInput
            style={[
              styles.searchInput,
              {
                backgroundColor: colors.storiaInputBg,
                color: colors.text,
                borderColor: colors.storiaBorder,
                fontFamily: fonts.sans,
              },
            ]}
            placeholder="Search books..."
            placeholderTextColor={colors.textSecondary}
            value={search}
            onChangeText={setSearch}
            autoCorrect={false}
          />
        </View>

        {/* Genre filter */}
        <FlatList
          data={GENRES}
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.genreList}
          keyExtractor={(item) => item}
          renderItem={({ item }) => {
            const isActive = item === 'All' ? genre === '' : genre === item;
            return (
              <TouchableOpacity
                style={[
                  styles.genreChip,
                  {
                    backgroundColor: isActive ? colors.storiaPrimary : colors.storiaInputBg,
                    borderColor: isActive ? colors.storiaPrimary : colors.storiaBorder,
                  },
                ]}
                onPress={() => setGenre(item === 'All' ? '' : item)}
              >
                <Text
                  style={[
                    styles.genreText,
                    {
                      color: isActive ? '#fff' : colors.text,
                      fontFamily: fonts.sans,
                    },
                  ]}
                >
                  {item}
                </Text>
              </TouchableOpacity>
            );
          }}
        />

        {/* Continue Reading */}
        {continueReading.length > 0 && (
          <View style={styles.continueSection}>
            <Text style={[styles.sectionTitle, { color: colors.text, fontFamily: fonts.sans }]}>
              Continue Reading
            </Text>
            <FlatList
              data={continueReading}
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.continueList}
              keyExtractor={(item) => item.id}
              renderItem={renderContinueCard}
            />
          </View>
        )}

        {/* All Books heading */}
        <Text style={[styles.sectionTitle, { color: colors.text, fontFamily: fonts.sans, marginTop: 16, marginHorizontal: CARD_PADDING }]}>
          All Books
        </Text>
      </View>
    ),
    [insets.top, colors, search, genre, continueReading, isOffline, renderContinueCard]
  );

  if (isLoading) {
    return (
      <View style={[styles.loadingContainer, { backgroundColor: colors.background }]}>
        <ActivityIndicator size="large" color={colors.storiaPrimary} />
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <FlatList
        data={allBooks}
        numColumns={NUM_COLUMNS}
        keyExtractor={(item) => item.id}
        renderItem={renderBookCard}
        ListHeaderComponent={ListHeader}
        contentContainerStyle={styles.grid}
        columnWrapperStyle={styles.row}
        onEndReached={() => {
          if (hasNextPage && !isFetchingNextPage) fetchNextPage();
        }}
        onEndReachedThreshold={0.5}
        refreshControl={
          <RefreshControl
            refreshing={isRefetching}
            onRefresh={refetch}
            tintColor={colors.storiaPrimary}
          />
        }
        ListFooterComponent={
          isFetchingNextPage ? (
            <ActivityIndicator style={{ padding: 16 }} color={colors.storiaPrimary} />
          ) : null
        }
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Text style={[styles.emptyText, { color: colors.textSecondary, fontFamily: fonts.sans }]}>
              No books found
            </Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  loadingContainer: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: CARD_PADDING,
    paddingBottom: 8,
  },
  headerTitle: { fontSize: 28, fontWeight: '700' },
  offlineBanner: {
    paddingVertical: 6,
    paddingHorizontal: CARD_PADDING,
    marginHorizontal: CARD_PADDING,
    borderRadius: 8,
    marginBottom: 8,
  },
  offlineText: { color: '#fff', fontSize: 13, textAlign: 'center', fontWeight: '500' },
  searchSection: { paddingHorizontal: CARD_PADDING, marginBottom: 12 },
  searchInput: {
    height: 44,
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 14,
    fontSize: 15,
  },
  genreList: { paddingHorizontal: CARD_PADDING, gap: 8, marginBottom: 16 },
  genreChip: {
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 20,
    borderWidth: 1,
  },
  genreText: { fontSize: 13, fontWeight: '500' },
  continueSection: { marginBottom: 8 },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    marginBottom: 12,
    marginHorizontal: CARD_PADDING,
  },
  continueList: { paddingHorizontal: CARD_PADDING, gap: 12 },
  continueCard: {
    width: 200,
    borderRadius: 12,
    overflow: 'hidden',
  },
  continueCover: { width: '100%', height: 120 },
  continueInfo: { padding: 10 },
  continueTitle: { fontSize: 14, fontWeight: '600' },
  continueProgressBar: { height: 4, borderRadius: 2, marginTop: 6 },
  continueProgressFill: { height: '100%', borderRadius: 2 },
  continuePercent: { fontSize: 11, marginTop: 4 },
  grid: { paddingBottom: 24 },
  row: { paddingHorizontal: CARD_PADDING, gap: CARD_GAP },
  card: {
    borderRadius: 12,
    overflow: 'hidden',
    marginBottom: CARD_GAP,
  },
  coverImage: {
    width: '100%',
    aspectRatio: 3 / 4,
  },
  badge: {
    position: 'absolute',
    top: 8,
    right: 8,
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: { fontSize: 12 },
  progressBar: {
    height: 3,
    width: '100%',
  },
  progressFill: { height: '100%' },
  bookTitle: {
    fontSize: 14,
    fontWeight: '600',
    paddingHorizontal: 8,
    paddingTop: 8,
  },
  bookAuthor: {
    fontSize: 12,
    paddingHorizontal: 8,
    paddingBottom: 10,
    paddingTop: 2,
  },
  emptyState: { padding: 40, alignItems: 'center' },
  emptyText: { fontSize: 16 },
});
