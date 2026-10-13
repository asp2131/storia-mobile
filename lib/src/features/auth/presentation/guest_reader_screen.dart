import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../audio/audio_engine.dart';
import '../../../audio/audio_providers.dart';
import '../../../audio/just_audio_player.dart';
import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../../routing/journey/journey_policy.dart';
import '../../reader/domain/reader_capabilities.dart';
import '../../reader/reader_screen.dart';
import '../../reader/runtime/providers/reader_capabilities_provider.dart';
import '../data/intro_books_provider.dart';
import '../domain/intro_book_selection.dart';

/// Check publication through the catalog before fetching full page/media data.
/// The detailed repository query itself does not filter publication status.
final guestReaderBookProvider = FutureProvider.autoDispose
    .family<Book?, String>((ref, bookId) async {
      if (!introBookIds.contains(bookId)) return null;
      final publishedBooks = await ref.watch(introBooksProvider.future);
      if (!publishedBooks.any((book) => book.id == bookId)) return null;
      return ref.watch(bookRepositoryProvider).getBookById(bookId);
    });

/// The account-free boundary for published intro stories. Invalid IDs never
/// fetch content or construct a reader runtime, even on a cold deep link.
class GuestReaderScreen extends ConsumerWidget {
  const GuestReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void exit() => context.go(JourneyRoutes.tryStory);

    final Widget content;
    if (!introBookIds.contains(bookId)) {
      content = _GuestReaderStatus(
        message: 'Choose a story to try with Loratone.',
        onExit: exit,
      );
    } else {
      content = ref
          .watch(guestReaderBookProvider(bookId))
          .when(
            loading: () => _GuestReaderStatus(onExit: exit),
            error: (_, _) => _GuestReaderStatus(
              message: 'This story could not be opened. Please try again.',
              onExit: exit,
              onRetry: () {
                ref.invalidate(introBooksProvider);
                ref.invalidate(guestReaderBookProvider(bookId));
              },
            ),
            data: (book) {
              if (book == null || book.pages.isEmpty) {
                return _GuestReaderStatus(
                  message: 'This story is not available right now.',
                  onExit: exit,
                );
              }
              return ProviderScope(
                key: ValueKey(bookId),
                overrides: [
                  readerCapabilitiesProvider.overrideWithValue(
                    const ReaderCapabilities(access: ReaderAccess.guest),
                  ),
                  // Bind the reader to the already-authorized full public book,
                  // without reading parent voice providers.
                  currentBookProvider(bookId).overrideWith((ref) async => book),
                  pageAudioProvider.overrideWith((ref) {
                    final engine = AudioEngine(
                      playerFactory: JustAudioPlayer.new,
                      autoplayPages: false,
                    );
                    ref.onDispose(engine.dispose);
                    return engine;
                  }),
                ],
                child: ReaderScreen(
                  bookId: bookId,
                  onExit: exit,
                  onFinished: exit,
                ),
              );
            },
          );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) exit();
      },
      child: content,
    );
  }
}

class _GuestReaderStatus extends StatelessWidget {
  const _GuestReaderStatus({required this.onExit, this.message, this.onRetry});

  final VoidCallback onExit;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StoriaColors.readerBackground,
      appBar: AppBar(
        backgroundColor: StoriaColors.readerBackground,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Choose another story',
          onPressed: onExit,
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Loratone'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(StoriaSpacing.xl),
          child: message == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: StoriaSpacing.lg),
                    if (onRetry != null)
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('Try again'),
                      ),
                    TextButton(
                      onPressed: onExit,
                      child: const Text('Choose another story'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
