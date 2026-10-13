import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/loratone_entry_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../routing/journey/journey_actions.dart';
import '../data/intro_books_provider.dart';
import 'widgets/intro_story_preview.dart';
import 'widgets/story_entry_widgets.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _previewKey = GlobalKey<IntroStoryPreviewState>();

  Future<void> _leave(VoidCallback navigate) async {
    await _previewKey.currentState?.stop();
    if (mounted) navigate();
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(introBooksProvider);
    final featuredBook = booksAsync.valueOrNull?.firstOrNull;

    return Scaffold(
      backgroundColor: LoratoneEntryColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      StoriaSpacing.xl,
                      StoriaSpacing.lg,
                      StoriaSpacing.xl,
                      StoriaSpacing.lg,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Loratone',
                          style: storyEntryText(
                            size: 26,
                            weight: FontWeight.w900,
                            color: LoratoneEntryColors.ink,
                          ),
                        ),
                        GrownUpsButton(
                          onPressed: () => unawaited(
                            _leave(() => enterAuth(context, AuthEntry.signUp)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: StoriaSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: (constraints.maxHeight * 0.47).clamp(
                              240.0,
                              420.0,
                            ),
                            width: double.infinity,
                            child: featuredBook != null
                                ? IntroStoryPreview(
                                    key: _previewKey,
                                    bookId: featuredBook.id,
                                  )
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: LoratoneEntryColors.sky,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: booksAsync.isLoading
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : StoryEntryMessage(
                                            message:
                                                'Our stories could not load. Check your connection and try again.',
                                            onRetry: () => ref.invalidate(
                                              introBooksProvider,
                                            ),
                                          ),
                                  ),
                          ),
                          const SizedBox(height: StoriaSpacing.xl),
                          Text(
                            'Stories that read\nto you',
                            style: storyEntryText(
                              size: 34,
                              weight: FontWeight.w900,
                              color: LoratoneEntryColors.coral,
                              height: 1.08,
                            ),
                          ),
                          const SizedBox(height: StoriaSpacing.md),
                          Text(
                            'Words light up as they’re read, with sound from inside the story.',
                            style: storyEntryText(
                              size: 17,
                              color: LoratoneEntryColors.inkMuted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: StoriaSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      StoriaSpacing.xl,
                      StoriaSpacing.lg,
                      StoriaSpacing.xl,
                      StoriaSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        StoryEntryButton(
                          label: 'Try a story',
                          onPressed: () =>
                              unawaited(_leave(() => tryStory(context))),
                        ),
                        const SizedBox(height: StoriaSpacing.sm),
                        TextButton(
                          onPressed: () => unawaited(
                            _leave(() => enterAuth(context, AuthEntry.signIn)),
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(44, 48),
                          ),
                          child: Text.rich(
                            TextSpan(
                              text: 'Have an account? ',
                              style: storyEntryText(
                                size: 15,
                                color: LoratoneEntryColors.inkMuted,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Sign in',
                                  style: storyEntryText(
                                    size: 15,
                                    weight: FontWeight.w900,
                                    color: LoratoneEntryColors.ink,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}
