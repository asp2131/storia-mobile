import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../application/narration_track_selection.dart';
import '../domain/narration_track.dart';
import 'narration_repository.dart';

final narrationHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final narrationRepositoryProvider = Provider<NarrationRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return NarrationRepository(
    client: ref.watch(narrationHttpClientProvider),
    apiBaseUrl: ref.watch(apiBaseUrlProvider),
    currentAccessToken: () => supabase.auth.currentSession?.accessToken,
  );
});

/// Tracks this account recorded for a book.
///
/// Failure is not fatal: the reader falls back to the published narration, so
/// a network hiccup must never block opening a book.
final bookNarrationTracksProvider =
    FutureProvider.family<List<NarrationTrack>, String>((ref, bookId) async {
      if (bookId.isEmpty) return const <NarrationTrack>[];

      try {
        final repo = ref.watch(narrationRepositoryProvider);
        return await repo.getTracksForBook(bookId);
      } catch (_) {
        return const <NarrationTrack>[];
      }
    });

String _selectionKey(String bookId) => 'narration_track:$bookId';

/// Which narration voice the reader should use for a book.
///
/// `null` means the published Storia voice.
class NarrationTrackSelection extends StateNotifier<String?> {
  NarrationTrackSelection(this._bookId) : super(null) {
    _restore();
  }

  final String _bookId;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_selectionKey(_bookId));
  }

  Future<void> select(String? trackId) async {
    state = trackId;
    final prefs = await SharedPreferences.getInstance();
    if (trackId == null) {
      await prefs.remove(_selectionKey(_bookId));
    } else {
      await prefs.setString(_selectionKey(_bookId), trackId);
    }
  }
}

final narrationTrackSelectionProvider =
    StateNotifierProvider.family<NarrationTrackSelection, String?, String>(
      (ref, bookId) => NarrationTrackSelection(bookId),
    );

/// The book the reader actually renders: published pages with the selected
/// parent narration swapped in.
final readerBookProvider = FutureProvider.family<Book?, String>((
  ref,
  bookId,
) async {
  final book = await ref.watch(currentBookProvider(bookId).future);
  if (book == null) return null;

  final tracks = await ref.watch(bookNarrationTracksProvider(bookId).future);
  final selectedId = ref.watch(narrationTrackSelectionProvider(bookId));

  return applyTrackToBook(book, resolveSelectedTrack(tracks, selectedId));
});
