import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../domain/narration_track.dart';

typedef NarrationAccessTokenResolver = String? Function();

class NarrationRepositoryException implements Exception {
  const NarrationRepositoryException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'NarrationRepositoryException($statusCode): $message';
}

/// Talks to the storia.kids narration routes.
///
/// Mirrors [ChildProfileRepository]: Supabase session token as Bearer, explicit
/// status-code checks, typed exception. Audio never goes to Supabase Storage
/// directly — the API owns upload + forced alignment so the ElevenLabs key and
/// service-role key stay server-side.
class NarrationRepository {
  NarrationRepository({
    required http.Client client,
    required String apiBaseUrl,
    required NarrationAccessTokenResolver currentAccessToken,
  }) : _client = client,
       _baseUrl = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _currentAccessToken = currentAccessToken;

  final http.Client _client;
  final String _baseUrl;
  final NarrationAccessTokenResolver _currentAccessToken;

  Map<String, String> _authHeaders({bool contentType = false}) {
    final token = _currentAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (contentType) 'Content-Type': 'application/json',
    };
  }

  Never _fail(String action, http.BaseResponse response) {
    throw NarrationRepositoryException(
      '$action failed with status ${response.statusCode}.',
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Narration response must be a JSON object.');
    }
    return decoded;
  }

  /// Tracks this account recorded for [bookId], newest last.
  Future<List<NarrationTrack>> getTracksForBook(String bookId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/books/$bookId/narrations'),
      headers: _authHeaders(),
    );

    if (response.statusCode != 200) _fail('Narration track request', response);

    final tracks = _decodeObject(response.body)['tracks'];
    if (tracks is! List) {
      throw const FormatException('Narration response is missing tracks.');
    }

    return tracks
        .whereType<Map<String, dynamic>>()
        .map(NarrationTrack.fromJson)
        .toList(growable: false);
  }

  Future<NarrationTrack> createTrack({
    required String bookId,
    required String label,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/narrations/tracks'),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({'bookId': bookId, 'label': label}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail('Narration track create', response);
    }

    final track = _decodeObject(response.body)['track'];
    if (track is! Map<String, dynamic>) {
      throw const FormatException('Create track response is missing track.');
    }
    return NarrationTrack.fromJson(track);
  }

  /// Uploads one page recording. Re-uploading the same page is a retake.
  Future<NarrationPageRecording> uploadPageRecording({
    required String trackId,
    required int pageNumber,
    required File audioFile,
    required Duration duration,
    String contentType = 'audio/mp4',
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/api/narrations/pages'),
          )
          ..headers.addAll(_authHeaders())
          ..fields['trackId'] = trackId
          ..fields['pageNumber'] = '$pageNumber'
          ..fields['durationMs'] = '${duration.inMilliseconds}'
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              audioFile.path,
              contentType: MediaType.parse(contentType),
            ),
          );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail('Narration upload', response);
    }

    final page = _decodeObject(response.body)['page'];
    if (page is! Map<String, dynamic>) {
      throw const FormatException('Upload response is missing page.');
    }
    return NarrationPageRecording.fromJson(page);
  }

  Future<NarrationTrack> setTrackReady(String trackId) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/narrations/tracks/$trackId'),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({'status': 'ready'}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail('Narration track update', response);
    }

    final track = _decodeObject(response.body)['track'];
    if (track is! Map<String, dynamic>) {
      throw const FormatException('Update track response is missing track.');
    }
    return NarrationTrack.fromJson(track);
  }

  Future<void> deleteTrack(String trackId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/narrations/tracks/$trackId'),
      headers: _authHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _fail('Narration track delete', response);
    }
  }
}
