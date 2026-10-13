import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/data/providers.dart';
import 'package:loratone/src/features/gen_ui/data/gen_ui_preferences_provider.dart';
import 'package:loratone/src/features/narration_studio/data/narration_providers.dart';
import 'package:loratone/src/features/reader/application/reader_experience_controller.dart';
import 'package:loratone/src/features/reader/application/reader_experience_effects.dart';
import 'package:loratone/src/features/reader/domain/reader_capabilities.dart';
import 'package:loratone/src/features/reader/reader_screen.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_capabilities_provider.dart';
import 'package:loratone/src/features/reader/runtime/providers/reader_session_provider.dart';
import 'package:loratone/src/features/reader/walkthrough/reader_walkthrough.dart';

import 'application/reader_experience_fakes.dart';

void main() {
  testWidgets(
    'guest page and audio mix do not read private or word-help providers',
    (tester) async {
      final session = FakeReaderSession();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readerCapabilitiesProvider.overrideWithValue(
              const ReaderCapabilities(access: ReaderAccess.guest),
            ),
            currentBookProvider('68').overrideWith((ref) async => _book),
            readerSessionProvider.overrideWithValue(session),
            readerExperienceEffectsProvider.overrideWithValue(
              const NoopReaderExperienceEffects(),
            ),
            readerExperienceWordHelpProvider(
              '68',
            ).overrideWith((ref) => throw StateError('word-help initialized')),
            readerBookProvider(
              '68',
            ).overrideWith((ref) => throw StateError('parent voices queried')),
            narrationTrackSelectionProvider('68').overrideWith(
              (ref) => throw StateError('parent voice selection initialized'),
            ),
            bookManifestProvider(
              '68',
            ).overrideWith((ref) => throw StateError('word manifest queried')),
            storySparksEnabledProvider.overrideWith(
              (ref) => throw StateError('activities initialized'),
            ),
            readerWalkthroughSeenProvider.overrideWith(
              (ref) => throw StateError('private walkthrough initialized'),
            ),
          ],
          child: const MaterialApp(home: ReaderScreen(bookId: '68')),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.mic_off_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Audio Mix'), findsOneWidget);
      expect(find.text('Story Sparks'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await session.dispose();
    },
  );
}

final _book = Book(
  id: '68',
  title: 'Public story',
  pageCount: 1,
  pages: const [
    PageData(id: '1', pageNumber: 1, textContent: 'A bright new day.'),
  ],
);
