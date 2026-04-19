import 'package:Storia_Kids/src/core/analytics/analytics_service.dart';
import 'package:Storia_Kids/src/features/reader/domain/reader_entry_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists reader_opened events through the injected sink', () async {
    final calls = <Map<String, dynamic>>[];
    final service = AnalyticsService(
      sink: (event, properties) async {
        calls.add({'event': event, 'properties': properties});
      },
    );

    service.trackReaderOpened(
      childId: 'child-1',
      bookId: '101',
      sessionId: 'rs_1',
      entryIntent: ReaderEntryIntent.standard,
      resumePage: 3,
    );

    await Future<void>.delayed(Duration.zero);

    expect(calls, hasLength(1));
    expect(calls.single['event'], 'reader_opened');
    expect(calls.single['properties'], containsPair('childId', 'child-1'));
    expect(calls.single['properties'], containsPair('bookId', '101'));
    expect(calls.single['properties'], containsPair('sessionId', 'rs_1'));
  });
}
