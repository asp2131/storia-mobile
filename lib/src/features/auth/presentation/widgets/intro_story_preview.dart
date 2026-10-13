import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../audio/audio_engine.dart';
import '../../../../audio/just_audio_player.dart';
import '../../../../audio/page_audio.dart';
import '../../../../core/theme/loratone_entry_colors.dart';
import '../../../../core/theme/storia_spacing.dart';
import '../../../../data/models.dart';
import '../../../../data/providers.dart';
import '../../../reader/overlay/text_overlay_utils.dart';
import 'intro_preview_illustration.dart';
import 'story_entry_widgets.dart';

class IntroStoryPreview extends ConsumerStatefulWidget {
  const IntroStoryPreview({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<IntroStoryPreview> createState() => IntroStoryPreviewState();
}

class IntroStoryPreviewState extends ConsumerState<IntroStoryPreview>
    with WidgetsBindingObserver {
  AudioEngine? _audio;
  StreamSubscription<AudioSnapshot>? _subscription;
  AudioSnapshot _snapshot = const AudioSnapshot();
  bool _loaded = false;
  bool _busy = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(IntroStoryPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) unawaited(stop());
  }

  /// Called before every navigation so a preview never plays under the reader.
  Future<void> stop() async {
    _generation++;
    _loaded = false;
    await _audio?.stopAll();
    if (mounted) setState(() => _snapshot = const AudioSnapshot());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _audio?.dispose();
    super.dispose();
  }

  void _playbackFailed(Object error) {
    if (!mounted) return;
    unawaited(stop());
    setState(() => _failed = true);
  }

  Future<void> _toggle(PageData page) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final generation = _generation;
    final engine = _audio ??= AudioEngine(
      playerFactory: JustAudioPlayer.new,
      autoplayPages: false,
    );
    _subscription ??= engine.states.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });
    try {
      if (!_loaded) {
        await engine.loadPage(page);
        if (!mounted || generation != _generation) return;
        _loaded = true;
      }
      // Raw play futures complete at the end of the track, not at its start.
      unawaited(engine.toggleNarration().catchError(_playbackFailed));
      if ((page.soundscapeUrl ?? '').isNotEmpty) {
        unawaited(engine.toggleSoundscape().catchError(_playbackFailed));
      }
    } catch (error) {
      _playbackFailed(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(currentBookProvider(widget.bookId));
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ColoredBox(
        color: LoratoneEntryColors.sky,
        child: bookAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _unavailable(),
          data: (book) {
            final page = book?.pages
                .where(
                  (page) =>
                      (page.narrationUrl ?? '').isNotEmpty &&
                      (page.imageUrl ?? '').isNotEmpty &&
                      (page.narrationTimestamps?.isNotEmpty ?? false),
                )
                .firstOrNull;
            if (book == null || page == null) return _unavailable();
            final timestamps = page.narrationTimestamps!;
            final activeWord = computeActiveWordIndex(
              timestamps,
              _snapshot.narrationPosition,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                IntroPreviewIllustration(imageUrl: page.imageUrl!),
                Positioned(
                  top: StoriaSpacing.lg,
                  left: StoriaSpacing.lg,
                  right: StoriaSpacing.lg,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: LoratoneEntryColors.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: StoriaSpacing.md,
                          vertical: StoriaSpacing.sm,
                        ),
                        child: Text(
                          _failed
                              ? 'Could not play. Tap to retry.'
                              : 'Tap play to hear it',
                          style: storyEntryText(
                            size: 13,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: StoriaSpacing.lg,
                  left: StoriaSpacing.lg,
                  right: StoriaSpacing.lg,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: LoratoneEntryColors.surface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(StoriaSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: storyEntryText(
                                    size: 13,
                                    weight: FontWeight.w800,
                                    color: LoratoneEntryColors.ink,
                                  ),
                                ),
                                const SizedBox(height: StoriaSpacing.xs),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      for (
                                        var i = 0;
                                        i < timestamps.length;
                                        i++
                                      )
                                        TextSpan(
                                          text: '${timestamps[i].word} ',
                                          style: _loaded && i == activeWord
                                              ? const TextStyle(
                                                  color:
                                                      LoratoneEntryColors.blue,
                                                  backgroundColor:
                                                      LoratoneEntryColors.sky,
                                                )
                                              : null,
                                        ),
                                    ],
                                  ),
                                  style: storyEntryText(
                                    size: 18,
                                    weight: FontWeight.w800,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: StoriaSpacing.md),
                          IconButton.filled(
                            tooltip: _snapshot.isNarrationPlaying
                                ? 'Pause story preview'
                                : 'Play story preview',
                            onPressed: _busy
                                ? null
                                : () => unawaited(_toggle(page)),
                            style: IconButton.styleFrom(
                              backgroundColor: LoratoneEntryColors.ink,
                              foregroundColor: LoratoneEntryColors.surface,
                              minimumSize: const Size(52, 52),
                            ),
                            icon: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _snapshot.isNarrationPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 28,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _unavailable() => StoryEntryMessage(
    message: 'The preview could not load. You can still pick a story below.',
    onRetry: () => ref.invalidate(currentBookProvider(widget.bookId)),
  );
}
