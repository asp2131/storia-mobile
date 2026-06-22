import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_card.dart';
import '../domain/sequencer.dart';
import 'aac_music_demo_controller.dart';

class AacMusicDemoScreen extends ConsumerWidget {
  const AacMusicDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aacMusicDemoControllerProvider);
    return Scaffold(
      backgroundColor: StoriaColors.paper,
      appBar: AppBar(
        backgroundColor: StoriaColors.paper,
        foregroundColor: StoriaColors.ink,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to library',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('AAC Music Demo'),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load board: $e')),
          data: (controller) => _DemoBody(controller: controller),
        ),
      ),
    );
  }
}

class _DemoBody extends StatefulWidget {
  const _DemoBody({required this.controller});
  final AacMusicDemoController controller;

  @override
  State<_DemoBody> createState() => _DemoBodyState();
}

class _DemoBodyState extends State<_DemoBody> {
  AacMusicDemoController get _c => widget.controller;
  late final RemoveListener _removeListener;
  late AacMusicDemoState _state;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // StateNotifier isn't a Listenable, so subscribe manually. addListener
    // fires synchronously with the current state, then on every change. The
    // callback hands us the state, so we never touch the protected getter.
    _removeListener = _c.addListener((state) {
      _state = state;
      if (_initialized && mounted) setState(() {});
    });
    _initialized = true;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = _state;
    final sentence = state.utteranceLabels.join(' ');
    return Padding(
      padding: const EdgeInsets.all(StoriaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SketchCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sentence.isEmpty
                        ? 'Tap words to build a sentence'
                        : sentence,
                    style: textTheme.titleLarge?.copyWith(
                      color: StoriaColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear sentence',
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: _c.clearUtterance,
                ),
              ],
            ),
          ),
          const SizedBox(height: StoriaSpacing.lg),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: StoriaSpacing.sm,
              crossAxisSpacing: StoriaSpacing.sm,
              childAspectRatio: 1.4,
              children: [
                for (final word in state.board.words)
                  ElevatedButton(
                    onPressed: () => _c.selectWord(word),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StoriaColors.paperRaised,
                      foregroundColor: StoriaColors.ink,
                    ),
                    child: Text(word.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: StoriaSpacing.md),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<MusicMode>(
                  segments: const [
                    ButtonSegment(value: MusicMode.off, label: Text('Off')),
                    ButtonSegment(
                        value: MusicMode.phraseOnly, label: Text('Phrase')),
                    ButtonSegment(
                        value: MusicMode.tapAndPhrase,
                        label: Text('Tap+Phrase')),
                  ],
                  selected: {state.mode},
                  onSelectionChanged: (s) => _c.setMode(s.first),
                ),
              ),
              const SizedBox(width: StoriaSpacing.sm),
              FilledButton.icon(
                onPressed: _c.send,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Speak + Play'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
