import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:storia_kids/src/data/analytics_repository.dart';

void main() {
  group('AnalyticsEventType', () {
    test('serializes required event names', () {
      expect(AnalyticsEventType.bookStarted.eventName, 'book_started');
      expect(AnalyticsEventType.bookCompleted.eventName, 'book_completed');
      expect(AnalyticsEventType.pageViewed.eventName, 'page_viewed');
      expect(AnalyticsEventType.pageInteracted.eventName, 'page_interacted');
      expect(AnalyticsEventType.narrationPlayed.eventName, 'narration_played');
      expect(
        AnalyticsEventType.soundscapePlayed.eventName,
        'soundscape_played',
      );
      expect(AnalyticsEventType.wordAudioPlayed.eventName, 'word_audio_played');
      expect(
        AnalyticsEventType.phonemeAudioPlayed.eventName,
        'phoneme_audio_played',
      );
      expect(
        AnalyticsEventType.speechAttemptStarted.eventName,
        'speech_attempt_started',
      );
      expect(
        AnalyticsEventType.speechAttemptCompleted.eventName,
        'speech_attempt_completed',
      );
      expect(
        AnalyticsEventType.readingSessionStarted.eventName,
        'reading_session_started',
      );
      expect(
        AnalyticsEventType.readingSessionEnded.eventName,
        'reading_session_ended',
      );
      expect(
        AnalyticsEventType.readingSessionDropOff.eventName,
        'reading_session_drop_off',
      );
    });
  });

  group('AnalyticsEvent serialization', () {
    test('builds backend payload with context in properties', () {
      final event = AnalyticsEvent(
        type: AnalyticsEventType.pageViewed,
        occurredAt: DateTime.parse('2026-04-17T10:00:00.000Z'),
        userId: 'user-1',
        childProfileId: 'child-1',
        bookId: '101',
        pageId: 'page-5',
        pageNumber: 5,
        sessionId: 'rs-1',
        metadata: const {'sourceButton': 'next', 'durationMs': 250},
      );

      expect(event.toApiJson(childProfileId: 'child-1'), {
        'event': 'page_viewed',
        'childProfileId': 'child-1',
        'source': 'mobile',
        'occurredAt': '2026-04-17T10:00:00.000Z',
        'sessionId': 'rs-1',
        'bookId': '101',
        'properties': {
          'sourceButton': 'next',
          'durationMs': 250,
          'userId': 'user-1',
          'childProfileId': 'child-1',
          'bookId': '101',
          'pageId': 'page-5',
          'pageNumber': 5,
          'sessionId': 'rs-1',
        },
      });
    });

    test('keeps non-BIGINT book ids in properties only', () {
      final event = AnalyticsEvent(
        type: AnalyticsEventType.bookStarted,
        occurredAt: DateTime.parse('2026-04-17T10:00:00.000Z'),
        bookId: 'book-uuid',
      );

      final body = event.toApiJson(childProfileId: 'child-1');

      expect(body.containsKey('bookId'), isFalse);
      expect(body['properties'], containsPair('bookId', 'book-uuid'));
    });

    test('sanitizes raw audio, transcripts, and binary metadata', () {
      final event = AnalyticsEvent(
        type: AnalyticsEventType.speechAttemptCompleted,
        occurredAt: DateTime.parse('2026-04-17T10:00:00.000Z'),
        metadata: {
          'score': 0.87,
          'matchedWordCount': 4,
          'audio': 'base64-audio',
          'raw_audio': 'base64-audio',
          'audioBytes': [1, 2, 3],
          'transcript': 'child speech should not be stored',
          'nested': {
            'recognizedWords': 'private child utterance',
            'confidence': 0.91,
            'bytes': Uint8List.fromList([1, 2, 3]),
            'scoredAt': DateTime.parse('2026-04-17T10:01:00.000Z'),
          },
        },
      );

      expect(event.toProperties(), {
        'score': 0.87,
        'matchedWordCount': 4,
        'nested': {'confidence': 0.91, 'scoredAt': '2026-04-17T10:01:00.000Z'},
      });
    });
  });

  group('AnalyticsRepository', () {
    test(
      'sends event with resolved user, child profile, and auth token',
      () async {
        final transport = _FakeAnalyticsTransport();
        final repository = AnalyticsRepository(
          transport: transport,
          clock: () => DateTime.parse('2026-04-17T10:00:00.000Z'),
          currentUserId: () => 'user-1',
          currentAccessToken: () => 'token-1',
          currentChildProfileId: () => 'child-1',
        );

        final didTrack = await repository.track(
          AnalyticsEventType.narrationPlayed,
          bookId: '101',
          pageId: 'page-2',
          pageNumber: 2,
          sessionId: 'rs-1',
          metadata: const {'durationMs': 1200},
        );

        expect(didTrack, isTrue);
        expect(transport.requests, hasLength(1));
        expect(transport.requests.single.accessToken, 'token-1');
        expect(transport.requests.single.body, {
          'event': 'narration_played',
          'childProfileId': 'child-1',
          'source': 'mobile',
          'occurredAt': '2026-04-17T10:00:00.000Z',
          'sessionId': 'rs-1',
          'bookId': '101',
          'properties': {
            'durationMs': 1200,
            'userId': 'user-1',
            'childProfileId': 'child-1',
            'bookId': '101',
            'pageId': 'page-2',
            'pageNumber': 2,
            'sessionId': 'rs-1',
          },
        });
      },
    );

    test('uses per-event childProfileId over resolver', () async {
      final transport = _FakeAnalyticsTransport();
      final repository = AnalyticsRepository(
        transport: transport,
        currentChildProfileId: () => 'resolver-child',
      );

      await repository.track(
        AnalyticsEventType.pageInteracted,
        childProfileId: 'event-child',
      );

      expect(transport.requests.single.body['childProfileId'], 'event-child');
      expect(transport.requests.single.body['properties'], {
        'childProfileId': 'event-child',
      });
    });

    test(
      'returns false and does not send when child profile is missing',
      () async {
        final transport = _FakeAnalyticsTransport();
        final repository = AnalyticsRepository(transport: transport);

        final didTrack = await _withSuppressedDebugPrint(
          () => repository.track(AnalyticsEventType.pageViewed),
        );

        expect(didTrack, isFalse);
        expect(transport.requests, isEmpty);
      },
    );

    test('returns false when transport throws', () async {
      final repository = AnalyticsRepository(
        transport: _FakeAnalyticsTransport()..error = StateError('network'),
        currentChildProfileId: () => 'child-1',
      );

      final didTrack = await _withSuppressedDebugPrint(
        () => repository.track(AnalyticsEventType.pageViewed),
      );

      expect(didTrack, isFalse);
    });
  });

  group('HttpAnalyticsTransport', () {
    test('posts JSON to backend endpoint with bearer token', () async {
      late http.Request capturedRequest;
      final client = MockClient((request) async {
        capturedRequest = request;
        return http.Response('{"ok":true}', 201);
      });
      final transport = HttpAnalyticsTransport(
        client: client,
        apiBaseUrl: 'https://storia.kids/',
      );

      await transport.send(const {
        'event': 'page_viewed',
        'childProfileId': 'child-1',
      }, accessToken: 'token-1');

      expect(
        capturedRequest.url.toString(),
        'https://storia.kids/api/analytics/events',
      );
      expect(capturedRequest.headers['authorization'], 'Bearer token-1');
      expect(
        capturedRequest.headers['content-type'],
        contains('application/json'),
      );
      expect(jsonDecode(capturedRequest.body), {
        'event': 'page_viewed',
        'childProfileId': 'child-1',
      });
    });

    test('throws on non-success status', () async {
      final transport = HttpAnalyticsTransport(
        client: MockClient((_) async => http.Response('nope', 500)),
        apiBaseUrl: 'https://storia.kids',
      );

      expect(
        () => transport.send(const {'event': 'page_viewed'}),
        throwsA(isA<AnalyticsTransportException>()),
      );
    });
  });
}

Future<T> _withSuppressedDebugPrint<T>(Future<T> Function() body) async {
  final previousDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  try {
    return await body();
  } finally {
    debugPrint = previousDebugPrint;
  }
}

class _FakeAnalyticsRequest {
  const _FakeAnalyticsRequest({required this.body, this.accessToken});

  final Map<String, dynamic> body;
  final String? accessToken;
}

class _FakeAnalyticsTransport implements AnalyticsTransport {
  final requests = <_FakeAnalyticsRequest>[];
  Object? error;

  @override
  Future<void> send(Map<String, dynamic> body, {String? accessToken}) async {
    final error = this.error;
    if (error != null) {
      throw error;
    }
    requests.add(_FakeAnalyticsRequest(body: body, accessToken: accessToken));
  }
}
