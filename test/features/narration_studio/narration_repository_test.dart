import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:loratone/src/features/narration_studio/data/narration_repository.dart';
import 'package:loratone/src/features/narration_studio/domain/narration_track.dart';

NarrationRepository buildRepository(
  Future<http.Response> Function(http.Request) handler, {
  String? token = 'test-token',
}) => NarrationRepository(
  client: MockClient(handler),
  apiBaseUrl: 'https://storia.kids/',
  currentAccessToken: () => token,
);

const _trackJson = {
  'id': 'track-1',
  'bookId': '7',
  'label': 'Mom',
  'status': 'ready',
  'pages': [
    {
      'pageId': '42',
      'pageNumber': 3,
      'audioUrl': 'https://cdn.test/mom.m4a',
      'durationMs': 4000,
      'wordCount': 4,
      'alignmentStatus': 'aligned',
      'wordTimestamps': [
        {'word': 'Once', 'start': 0, 'end': 0.5},
        {'word': 'upon', 'start': 0.5, 'end': 1},
      ],
    },
  ],
};

void main() {
  group('getTracksForBook', () {
    test('sends the bearer token and trims a trailing slash from the base url', () async {
      late http.Request captured;
      final repo = buildRepository((request) async {
        captured = request;
        return http.Response(jsonEncode({'tracks': []}), 200);
      });

      await repo.getTracksForBook('7');

      expect(captured.url.toString(), 'https://storia.kids/api/books/7/narrations');
      expect(captured.headers['Authorization'], 'Bearer test-token');
    });

    test('omits the auth header when there is no session', () async {
      late http.Request captured;
      final repo = buildRepository((request) async {
        captured = request;
        return http.Response(jsonEncode({'tracks': []}), 200);
      }, token: null);

      await repo.getTracksForBook('7');

      expect(captured.headers.containsKey('Authorization'), isFalse);
    });

    test('parses tracks, pages, timings and alignment status', () async {
      final repo = buildRepository(
        (_) async => http.Response(
          jsonEncode({
            'tracks': [_trackJson],
          }),
          200,
        ),
      );

      final tracks = await repo.getTracksForBook('7');

      expect(tracks, hasLength(1));
      final track = tracks.single;
      expect(track.id, 'track-1');
      expect(track.label, 'Mom');
      expect(track.isReady, isTrue);

      final page = track.pageFor(3)!;
      expect(page.audioUrl, 'https://cdn.test/mom.m4a');
      expect(page.wordCount, 4);
      expect(page.alignment, NarrationAlignment.aligned);
      expect(page.wordTimestamps, hasLength(2));
      expect(page.wordTimestamps.first.word, 'Once');
      expect(page.wordTimestamps.first.end, 0.5);
    });

    test('treats a draft track as not selectable', () async {
      final repo = buildRepository(
        (_) async => http.Response(
          jsonEncode({
            'tracks': [
              {..._trackJson, 'status': 'draft'},
            ],
          }),
          200,
        ),
      );

      expect((await repo.getTracksForBook('7')).single.isReady, isFalse);
    });

    test('maps unknown alignment values to pending', () async {
      final repo = buildRepository(
        (_) async => http.Response(
          jsonEncode({
            'tracks': [
              {
                ..._trackJson,
                'pages': [
                  {
                    ...(_trackJson['pages']! as List).first
                        as Map<String, Object?>,
                    'alignmentStatus': 'weird',
                  },
                ],
              },
            ],
          }),
          200,
        ),
      );

      final page = (await repo.getTracksForBook('7')).single.pageFor(3)!;
      expect(page.alignment, NarrationAlignment.pending);
      expect(page.alignment.isReliable, isFalse);
    });

    test('throws a typed exception carrying the status code', () async {
      final repo = buildRepository((_) async => http.Response('nope', 401));

      await expectLater(
        repo.getTracksForBook('7'),
        throwsA(
          isA<NarrationRepositoryException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });

    test('rejects a malformed payload', () async {
      final repo = buildRepository(
        (_) async => http.Response(jsonEncode({'nope': true}), 200),
      );

      await expectLater(repo.getTracksForBook('7'), throwsA(isA<FormatException>()));
    });
  });

  group('createTrack', () {
    test('posts the book id and label', () async {
      late http.Request captured;
      final repo = buildRepository((request) async {
        captured = request;
        return http.Response(jsonEncode({'track': _trackJson}), 201);
      });

      final track = await repo.createTrack(bookId: '7', label: 'Mom');

      expect(captured.url.path, '/api/narrations/tracks');
      expect(jsonDecode(captured.body), {'bookId': '7', 'label': 'Mom'});
      expect(track.id, 'track-1');
    });

    test('throws on a limit-reached response', () async {
      final repo = buildRepository((_) async => http.Response('{}', 409));

      await expectLater(
        repo.createTrack(bookId: '7', label: 'Mom'),
        throwsA(
          isA<NarrationRepositoryException>().having(
            (e) => e.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
    });
  });

  group('setTrackReady', () {
    test('patches status to ready', () async {
      late http.Request captured;
      final repo = buildRepository((request) async {
        captured = request;
        return http.Response(jsonEncode({'track': _trackJson}), 200);
      });

      final track = await repo.setTrackReady('track-1');

      expect(captured.method, 'PATCH');
      expect(captured.url.path, '/api/narrations/tracks/track-1');
      expect(jsonDecode(captured.body), {'status': 'ready'});
      expect(track.isReady, isTrue);
    });
  });

  group('deleteTrack', () {
    test('issues a DELETE and tolerates an empty body', () async {
      late http.Request captured;
      final repo = buildRepository((request) async {
        captured = request;
        return http.Response('', 204);
      });

      await repo.deleteTrack('track-1');

      expect(captured.method, 'DELETE');
      expect(captured.url.path, '/api/narrations/tracks/track-1');
    });
  });
}
