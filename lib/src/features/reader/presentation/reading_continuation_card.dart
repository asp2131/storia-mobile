import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_spacing.dart';
import '../../../data/models.dart';
import '../../../routing/journey/journey_actions.dart';
import '../../../routing/journey/journey_policy.dart';
import '../../onboarding/data/sample_book_provider.dart';
import '../data/reading_checkpoint_provider.dart';
import '../domain/reader_capabilities.dart';

class ReadingContinuationCard extends ConsumerWidget {
  const ReadingContinuationCard({super.key, required this.publishedBooks});
  final List<Book> publishedBooks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkpoint = ref.watch(readingContinuationProvider);
    return checkpoint.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Card(
        child: ListTile(
          title: const Text('Your saved reading place is unavailable.'),
          trailing: TextButton(
            onPressed: () => ref.invalidate(readingContinuationProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
      data: (record) {
        if (record == null) return const SizedBox.shrink();
        final id = record.completed ? record.savedNextBookId! : record.bookId;
        String? title;
        if (id == sampleBookId) {
          final sample = ref.watch(sampleBookBundleProvider);
          if (sample.isLoading) return const SizedBox.shrink();
          title = sample.valueOrNull?.book.title;
        } else {
          for (final book in publishedBooks) {
            if (book.id == id) {
              title = book.title;
              break;
            }
          }
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(StoriaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title == null
                      ? 'Your saved story is unavailable right now.'
                      : record.completed
                      ? 'Saved for later: $title'
                      : 'Continue $title',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Saved on this device'),
                if (title != null)
                  FilledButton(
                    onPressed: () {
                      if (id == sampleBookId) {
                        startSample(ref, context);
                      } else {
                        context.go(JourneyRoutes.reader(id));
                      }
                    },
                    child: const Text('Open story'),
                  ),
                if (title == null)
                  TextButton(
                    onPressed: () {
                      ref.invalidate(readingContinuationProvider);
                      if (id == sampleBookId) {
                        ref.invalidate(sampleBookBundleProvider);
                      }
                    },
                    child: const Text('Retry saved story'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
