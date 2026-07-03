import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:loratone/src/features/aac_music_demo/domain/word_model.dart';
import 'package:loratone/src/features/aac_music_demo/domain/consonance_engine.dart';
import 'package:loratone/src/features/aac_music_demo/domain/role_resolver.dart';
import 'package:loratone/src/features/aac_music_demo/domain/sequencer.dart';
import 'package:loratone/src/features/aac_music_demo/data/aac_board.dart';
import 'package:loratone/src/features/aac_music_demo/presentation/aac_music_demo_controller.dart';
import 'package:loratone/src/features/aac_music_demo/presentation/aac_music_demo_screen.dart';

class _SilentSpeech implements SpeechSynth {
  @override
  Future<void> speak(String text) async {}
}

class _SilentBackend implements AudioBackend {
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> playPitches(List<Pitch> pitches, double gain) async {}
}

AacMusicDemoController _fakeController() {
  const board = AacBoard(
    palette: HarmonicPalette(root: PitchClass.c, scale: Scale.majorPentatonic),
    musicConfig: BoardMusicConfig(),
    words: [
      AacWord(id: 'i', label: 'I', row: 0, col: 0, musicalRole: MusicalRole.note(0)),
      AacWord(id: 'want', label: 'want', row: 0, col: 1, musicalRole: MusicalRole.note(3)),
      AacWord(id: 'more', label: 'more', row: 0, col: 2, musicalRole: MusicalRole.note(4)),
    ],
  );
  return AacMusicDemoController(
    board: board,
    sequencer: UtteranceSequencer(
      speech: _SilentSpeech(),
      backend: _SilentBackend(),
      engine: ConsonanceEngine(board.palette),
      resolver: RoleResolver(board.musicConfig),
    ),
  );
}

void main() {
  testWidgets('renders board words and builds an utterance on tap', (tester) async {
    final controller = _fakeController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aacMusicDemoControllerProvider.overrideWith((ref) async => controller),
        ],
        child: const MaterialApp(home: AacMusicDemoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'I'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'I'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'want'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'more'));
    await tester.pump();

    expect(find.text('I want more'), findsOneWidget);
  });

  testWidgets('clear empties the sentence strip', (tester) async {
    final controller = _fakeController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aacMusicDemoControllerProvider.overrideWith((ref) async => controller),
        ],
        child: const MaterialApp(home: AacMusicDemoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'I'));
    await tester.pump();
    await tester.tap(find.byTooltip('Clear sentence'));
    await tester.pump();

    expect(find.text('I'), findsOneWidget); // still on the board button
    expect(find.text('I want more'), findsNothing);
  });
}
