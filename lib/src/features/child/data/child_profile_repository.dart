import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_profile.dart';

typedef ChildProfileAccessTokenResolver = String? Function();

class ChildProfileRepository {
  ChildProfileRepository({
    required http.Client client,
    required String apiBaseUrl,
    SupabaseClient? supabase,
    ChildProfileAccessTokenResolver? currentAccessToken,
  }) : assert(
         supabase != null || currentAccessToken != null,
         'Provide either supabase or currentAccessToken.',
       ),
       _client = client,
       _endpoint = _childProfilesEndpoint(apiBaseUrl),
       _currentAccessToken =
           currentAccessToken ??
           (() => supabase!.auth.currentSession?.accessToken);

  final http.Client _client;
  final Uri _endpoint;
  final ChildProfileAccessTokenResolver _currentAccessToken;

  Future<List<ChildProfile>> getChildProfiles() async {
    final response = await _client.get(_endpoint, headers: _authHeaders());

    if (response.statusCode != 200) {
      throw ChildProfileRepositoryException(
        'Child profile request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Child profile response must be a JSON object.',
      );
    }

    final rawProfiles = decoded['childProfiles'];
    if (rawProfiles is! List) {
      throw const FormatException(
        'Child profile response is missing childProfiles.',
      );
    }

    return rawProfiles
        .whereType<Map<String, dynamic>>()
        .map(ChildProfile.fromJson)
        .toList(growable: false);
  }

  Future<ChildProfile> createChildProfile(CreateChildProfileInput input) async {
    final response = await _client.post(
      _endpoint,
      headers: _authHeaders(contentType: true),
      body: jsonEncode(input.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChildProfileRepositoryException(
        'Child profile create request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Create child profile response must be a JSON object.',
      );
    }

    final rawProfile = decoded['childProfile'];
    if (rawProfile is! Map<String, dynamic>) {
      throw const FormatException(
        'Create child profile response is missing childProfile.',
      );
    }

    return ChildProfile.fromJson(rawProfile);
  }

  Map<String, String> _authHeaders({bool contentType = false}) {
    final accessToken = _currentAccessToken();
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const ChildProfileAuthException(
        'Sign in again to load child profiles.',
      );
    }

    return <String, String>{
      'accept': 'application/json',
      if (contentType) 'content-type': 'application/json; charset=UTF-8',
      'authorization': 'Bearer $accessToken',
    };
  }

  static Uri _childProfilesEndpoint(String apiBaseUrl) {
    final trimmed = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final base = trimmed.isEmpty ? 'https://storia.kids' : trimmed;
    return Uri.parse('$base/api/child-profiles');
  }
}

class ChildProfileAuthException implements Exception {
  const ChildProfileAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChildProfileRepositoryException implements Exception {
  const ChildProfileRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
