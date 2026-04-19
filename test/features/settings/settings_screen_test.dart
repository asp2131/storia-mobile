import 'package:Storia_Kids/src/features/child/domain/child_profile.dart';
import 'package:Storia_Kids/src/features/child/providers/active_child_provider.dart';
import 'package:Storia_Kids/src/features/reports/domain/report_summary.dart';
import 'package:Storia_Kids/src/features/reports/providers/report_providers.dart';
import 'package:Storia_Kids/src/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeActiveChildNotifier extends ActiveChildNotifier {
  _FakeActiveChildNotifier(this.child);

  final ChildProfile? child;

  @override
  Future<ChildProfile?> build() async => child;
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  ChildProfile? child,
  required Future<ReportSummary?> Function() loadSummary,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeChildProvider.overrideWith(() => _FakeActiveChildNotifier(child)),
        reportSummaryProvider.overrideWith((ref) => loadSummary()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
}

void main() {
  testWidgets('shows report summary metrics and export CTA', (tester) async {
    await _pumpSettings(
      tester,
      child: const ChildProfile(
        id: 'child-1',
        displayName: 'Ava',
        ageBand: '6-8',
        isDefault: true,
      ),
      loadSummary: () async => const ReportSummary(
        childProfileId: 'child-1',
        range: '30d',
        booksStarted: 4,
        booksCompleted: 2,
        totalSessions: 8,
        totalReadingMinutes: 96,
        averageSessionMinutes: 12,
        comprehensionAttempts: 10,
        averageComprehensionScore: 80,
        practiceSessions: 3,
        practiceMinutes: 21,
        practiceSessionRatePercent: 38,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reading progress'), findsOneWidget);
    expect(find.text('Ava · 6-8'), findsOneWidget);
    expect(find.text('96m'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Practice summary'), findsOneWidget);
    expect(find.text('Export summary CSV'), findsOneWidget);
  });

  testWidgets('shows retry state when summary fails to load', (tester) async {
    await _pumpSettings(
      tester,
      child: const ChildProfile(
        id: 'child-1',
        displayName: 'Ava',
        ageBand: '6-8',
        isDefault: true,
      ),
      loadSummary: () => Future<ReportSummary?>.error(Exception('boom')),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Could not load the progress summary'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
