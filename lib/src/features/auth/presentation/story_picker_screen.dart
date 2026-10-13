import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/loratone_entry_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../data/models.dart';
import '../../../routing/journey/journey_actions.dart';
import '../data/intro_books_provider.dart';
import 'widgets/story_entry_widgets.dart';

class StoryPickerScreen extends ConsumerStatefulWidget {
  const StoryPickerScreen({super.key});

  @override
  ConsumerState<StoryPickerScreen> createState() => _StoryPickerScreenState();
}

class _StoryPickerScreenState extends ConsumerState<StoryPickerScreen> {
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(introBooksProvider);
    final books = booksAsync.valueOrNull ?? const <Book>[];
    final selected =
        books.where((book) => book.id == _selectedBookId).firstOrNull ??
        books.firstOrNull;

    return Scaffold(
      backgroundColor: LoratoneEntryColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    StoriaSpacing.xl,
                    StoriaSpacing.lg,
                    StoriaSpacing.xl,
                    StoriaSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Back to Loratone',
                        style: IconButton.styleFrom(
                          backgroundColor: LoratoneEntryColors.surface,
                          foregroundColor: LoratoneEntryColors.ink,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => backOutOfJourneyStep(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                      ),
                      const GrownUpsButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: booksAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _unavailable(),
                    data: (books) {
                      if (books.isEmpty) return _unavailable();
                      return ListView(
                        padding: const EdgeInsets.all(StoriaSpacing.xl),
                        children: [
                          Text(
                            'Pick a story',
                            style: storyEntryText(
                              size: 32,
                              weight: FontWeight.w900,
                              color: LoratoneEntryColors.coral,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: StoriaSpacing.sm),
                          Text(
                            'A little taste of Loratone. No account needed.',
                            style: storyEntryText(
                              color: LoratoneEntryColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: StoriaSpacing.xl),
                          for (final book in books) ...[
                            _StoryChoice(
                              book: book,
                              selected: selected?.id == book.id,
                              onTap: () =>
                                  setState(() => _selectedBookId = book.id),
                            ),
                            const SizedBox(height: StoriaSpacing.md),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    StoriaSpacing.xl,
                    StoriaSpacing.sm,
                    StoriaSpacing.xl,
                    StoriaSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      StoryEntryButton(
                        label: selected == null
                            ? 'Choose a story'
                            : 'Read ${selected.title}',
                        onPressed: selected == null
                            ? null
                            : () => readGuestStory(context, selected.id),
                      ),
                      const SizedBox(height: StoriaSpacing.md),
                      Text(
                        'Try the whole book, with narration and sound.',
                        textAlign: TextAlign.center,
                        style: storyEntryText(
                          size: 13,
                          color: LoratoneEntryColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unavailable() => StoryEntryMessage(
    message: 'Our stories could not load. Check your connection and try again.',
    onRetry: () => ref.invalidate(introBooksProvider),
  );
}

class _StoryChoice extends StatelessWidget {
  const _StoryChoice({
    required this.book,
    required this.selected,
    required this.onTap,
  });

  final Book book;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${book.title}, ${book.pageCount} pages',
    child: Material(
      color: LoratoneEntryColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: selected ? LoratoneEntryColors.blue : LoratoneEntryColors.line,
          width: selected ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(StoriaSpacing.md),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 88,
                  height: 118,
                  // Not CachedNetworkImage: on web it re-decodes on remount,
                  // and the shared <img> source is cleared under the new
                  // frame, so covers paint black after returning here.
                  child: ColoredBox(
                    color: LoratoneEntryColors.sky,
                    child: Image.network(
                      book.coverUrl ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.auto_stories_rounded,
                        color: LoratoneEntryColors.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: StoriaSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: storyEntryText(
                        size: 22,
                        weight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: StoriaSpacing.sm),
                    Text(
                      '${book.pageCount} pages',
                      style: storyEntryText(
                        size: 14,
                        color: LoratoneEntryColors.inkMuted,
                      ),
                    ),
                    if (book.author case final author?
                        when author.isNotEmpty) ...[
                      const SizedBox(height: StoriaSpacing.xs),
                      Text(
                        'By $author',
                        style: storyEntryText(
                          size: 13,
                          color: LoratoneEntryColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: StoriaSpacing.sm),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected
                    ? LoratoneEntryColors.blue
                    : LoratoneEntryColors.line,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
