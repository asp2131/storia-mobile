import 'package:Storia_Kids/src/features/child/domain/child_profile.dart';
import 'package:Storia_Kids/src/features/child/providers/active_child_provider.dart';
import 'package:Storia_Kids/src/features/reports/domain/report_summary.dart';
import 'package:Storia_Kids/src/features/reports/providers/report_providers.dart';
import 'package:Storia_Kids/src/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestActiveChildNotifier extends ActiveChildNotifier {
  @override
  Future<ChildProfile?> build() async {
    return const ChildProfile(
      id: 'child-1',
      displayName: 'Ava',
      ageBand: '6-8',
      isDefault: true,
    );
  }
}

void main() {
  testWidgets('shows report summary and CSV export action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeChildProvider.overrideWith(_TestActiveChildNotifier.new),
          reportSummaryProvider.overrideWith(
            (ref) async => const ReportSummary(
              childProfileId: 'child-1',
              range: '30d',
              booksStarted: 5,
              booksCompleted: 2,
              totalSessions: 8,
              totalReadingMinutes: 96,
              averageSessionMinutes: 12,
              comprehensionAttempts: 4,
              averageComprehensionScore: 75,
              practiceSessions: 3,
              practiceMinutes: 18,
              practiceSessionRatePercent: 38,
            ),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reading progress'), findsOneWidget);
    expect(find.textContaining('3 practice sessions'), findsOneWidget);
    expect(find.text('Export summary CSV'), findsOneWidget);
  });

  testWidgets('shows retry state when summary fails to load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeChildProvider.overrideWith(_TestActiveChildNotifier.new),
          reportSummaryProvider.overrideWith(
            (ref) => Future<ReportSummary?>.error(Exception('boom')),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Could not load the progress summary'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
