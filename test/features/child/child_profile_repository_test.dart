import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storia_kids/src/features/child/data/child_profile_providers.dart';
import 'package:storia_kids/src/features/child/data/child_profile_repository.dart';
import 'package:storia_kids/src/features/child/domain/child_profile.dart';

void main() {
  group('ChildProfile', () {
    test('parses backend JSON fields', () {
      final profile = ChildProfile.fromJson({
        'id': 'child-1',
        'userId': 'user-1',
        'displayName': 'Maya Reader',
        'ageBand': '6-8',
        'readingLevel': 'emerging',
        'isDefault': true,
        'createdAt': '2026-04-17T10:00:00.000Z',
        'updatedAt': '2026-04-18T10:00:00.000Z',
      });

      expect(profile.id, 'child-1');
      expect(profile.userId, 'user-1');
      expect(profile.displayName, 'Maya Reader');
      expect(profile.ageBand, '6-8');
      expect(profile.readingLevel, 'emerging');
      expect(profile.isDefault, isTrue);
      expect(profile.initials, 'MR');
      expect(profile.createdAt, DateTime.parse('2026-04-17T10:00:00.000Z'));
    });

    test('throws FormatException when required fields are missing', () {
      expect(
        () => ChildProfile.fromJson(const {'id': 'child-1'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('serializes create input with trimmed optional reading level', () {
      final input = CreateChildProfileInput(
        displayName: '  Ava  ',
        ageBand: ' 7-9 ',
        readingLevel: ' Early reader ',
        isDefault: true,
      );

      expect(input.toJson(), {
        'displayName': 'Ava',
        'ageBand': '7-9',
        'readingLevel': 'Early reader',
        'isDefault': true,
      });

      expect(
        const CreateChildProfileInput(
          displayName: 'Ava',
          ageBand: '7-9',
          readingLevel: '   ',
          isDefault: false,
        ).toJson(),
        {
          'displayName': 'Ava',
          'ageBand': '7-9',
          'readingLevel': null,
          'isDefault': false,
        },
      );
    });
  });

  group('ChildProfileRepository', () {
    test('GETs child profiles with Supabase bearer token', () async {
      late http.Request capturedRequest;
      final repository = ChildProfileRepository(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'childProfiles': [
                {
                  'id': 'child-1',
                  'displayName': 'Maya',
                  'ageBand': '6-8',
                  'readingLevel': null,
                  'isDefault': false,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        apiBaseUrl: 'https://storia.kids/',
        currentAccessToken: () => 'token-1',
      );

      final profiles = await repository.getChildProfiles();

      expect(
        capturedRequest.url.toString(),
        'https://storia.kids/api/child-profiles',
      );
      expect(capturedRequest.headers['authorization'], 'Bearer token-1');
      expect(profiles, hasLength(1));
      expect(profiles.single.id, 'child-1');
    });

    test('POSTs child profile with Supabase bearer token', () async {
      late http.Request capturedRequest;
      final repository = ChildProfileRepository(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              'childProfile': {
                'id': 'child-2',
                'displayName': 'Ava',
                'ageBand': '7-9',
                'readingLevel': 'Early reader',
                'isDefault': true,
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        apiBaseUrl: 'https://storia.kids/',
        currentAccessToken: () => 'token-1',
      );

      final created = await repository.createChildProfile(
        const CreateChildProfileInput(
          displayName: ' Ava ',
          ageBand: '7-9',
          readingLevel: 'Early reader',
          isDefault: true,
        ),
      );

      expect(capturedRequest.method, 'POST');
      expect(
        capturedRequest.url.toString(),
        'https://storia.kids/api/child-profiles',
      );
      expect(capturedRequest.headers['authorization'], 'Bearer token-1');
      expect(
        capturedRequest.headers['content-type'],
        contains('application/json'),
      );
      expect(jsonDecode(capturedRequest.body), {
        'displayName': 'Ava',
        'ageBand': '7-9',
        'readingLevel': 'Early reader',
        'isDefault': true,
      });
      expect(created.id, 'child-2');
    });

    test('throws auth exception without an access token', () async {
      final repository = ChildProfileRepository(
        client: MockClient((_) async => http.Response('{}', 200)),
        apiBaseUrl: 'https://storia.kids',
        currentAccessToken: () => null,
      );

      expect(
        repository.getChildProfiles,
        throwsA(isA<ChildProfileAuthException>()),
      );
    });

    test('throws repository exception on non-success status', () async {
      final repository = ChildProfileRepository(
        client: MockClient((_) async => http.Response('nope', 403)),
        apiBaseUrl: 'https://storia.kids',
        currentAccessToken: () => 'token-1',
      );

      expect(
        repository.getChildProfiles,
        throwsA(
          isA<ChildProfileRepositoryException>().having(
            (error) => error.statusCode,
            'statusCode',
            403,
          ),
        ),
      );
    });
  });

  group('ActiveChildProfileIdNotifier', () {
    test('loads and persists active id per signed-in user', () async {
      SharedPreferences.setMockInitialValues({
        'activeChildProfileId.user-1': 'child-1',
      });
      final notifier = ActiveChildProfileIdNotifier(userId: 'user-1');

      await notifier.load();

      expect(notifier.state.valueOrNull, 'child-1');

      await notifier.setActiveChildProfileId('child-2');
      final prefs = await SharedPreferences.getInstance();

      expect(notifier.state.valueOrNull, 'child-2');
      expect(prefs.getString('activeChildProfileId.user-1'), 'child-2');
    });

    test('clears state when there is no signed-in user', () async {
      SharedPreferences.setMockInitialValues({
        'activeChildProfileId.user-1': 'child-1',
      });
      final notifier = ActiveChildProfileIdNotifier(userId: null);

      await notifier.load();
      await notifier.setActiveChildProfileId('child-2');

      expect(notifier.state.valueOrNull, isNull);
    });
  });
}
