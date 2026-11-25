import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Analytics events persisted by the existing backend
/// `mobile_analytics_events` table via `POST /api/analytics/events`.
enum AnalyticsEventType {
  bookStarted('book_started'),
  bookCompleted('book_completed'),
  pageViewed('page_viewed'),
  pageInteracted('page_interacted'),
  narrationPlayed('narration_played'),
  soundscapePlayed('soundscape_played'),
  wordAudioPlayed('word_audio_played'),
  phonemeAudioPlayed('phoneme_audio_played'),
  speechAttemptStarted('speech_attempt_started'),
  speechAttemptCompleted('speech_attempt_completed'),
  readingSessionStarted('reading_session_started'),
  readingSessionEnded('reading_session_ended'),
  readingSessionDropOff('reading_session_drop_off'),
  narrationRecordingStarted('narration_recording_started'),
  narrationPageRecorded('narration_page_recorded'),
  narrationAlignmentFallback('narration_alignment_fallback'),
  narrationTrackCompleted('narration_track_completed'),
  narrationTrackSelected('narration_track_selected'),
  // Funnel + pulse events. Sent without a child profile; the backend stores
  // them against the signed-in user only.
  appOpened('app_opened'),
  signupCompleted('signup_completed'),
  signinCompleted('signin_completed'),
  onboardingCompleted('onboarding_completed'),
  childProfileCreated('child_profile_created'),
  libraryBookOpened('library_book_opened'),
  parentPulseAnswered('parent_pulse_answered');

  const AnalyticsEventType(this.eventName);

  final String eventName;
}

typedef AnalyticsValue = Object?;
typedef AnalyticsMetadata = Map<String, AnalyticsValue>;
typedef AnalyticsClock = DateTime Function();
typedef AnalyticsStringResolver = String? Function();

/// Strongly-typed analytics event with optional reader context.
///
/// Do not place raw child audio or speech transcripts in [metadata]. The
/// serializer defensively removes common raw-audio/transcript keys and binary
/// payload values before sending properties to the backend.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent({
    required this.type,
    required this.occurredAt,
    this.userId,
    this.childProfileId,
    this.bookId,
    this.pageId,
    this.pageNumber,
    this.sessionId,
    this.metadata = const {},
  });

  final AnalyticsEventType type;
  final DateTime occurredAt;
  final String? userId;
  final String? childProfileId;
  final String? bookId;
  final String? pageId;
  final int? pageNumber;
  final String? sessionId;
  final AnalyticsMetadata metadata;

  AnalyticsEvent copyWith({
    AnalyticsEventType? type,
    DateTime? occurredAt,
    String? userId,
    String? childProfileId,
    String? bookId,
    String? pageId,
    int? pageNumber,
    String? sessionId,
    AnalyticsMetadata? metadata,
  }) {
    return AnalyticsEvent(
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      userId: userId ?? this.userId,
      childProfileId: childProfileId ?? this.childProfileId,
      bookId: bookId ?? this.bookId,
      pageId: pageId ?? this.pageId,
      pageNumber: pageNumber ?? this.pageNumber,
      sessionId: sessionId ?? this.sessionId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toProperties() {
    final properties = <String, dynamic>{
      ...AnalyticsMetadataSanitizer.sanitize(metadata),
    };

    void addString(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        properties[key] = value;
      }
    }

    addString('userId', userId);
    addString('childProfileId', childProfileId);
    addString('bookId', bookId);
    addString('pageId', pageId);
    if (pageNumber != null) {
      properties['pageNumber'] = pageNumber;
    }
    addString('sessionId', sessionId);

    return properties;
  }

  Map<String, dynamic> toApiJson({String? childProfileId}) {
    final body = <String, dynamic>{
      'event': type.eventName,
      if (childProfileId != null && childProfileId.trim().isNotEmpty)
        'childProfileId': childProfileId,
      'source': 'mobile',
      'occurredAt': occurredAt.toUtc().toIso8601String(),
      'properties': toProperties(),
    };

    if (sessionId != null && sessionId!.trim().isNotEmpty) {
      body['sessionId'] = sessionId;
    }

    // The backend column is BIGINT. Keep non-numeric/mobile-local IDs in
    // properties only so analytics failures never block the reader.
    if (_isPositiveIntegerString(bookId)) {
      body['bookId'] = bookId;
    }

    return body;
  }
}

/// Defensively strips raw child audio, binary payloads, and speech transcripts
/// from analytics metadata while keeping JSON-compatible scores and context.
class AnalyticsMetadataSanitizer {
  const AnalyticsMetadataSanitizer._();

  static const Set<String> _blockedNormalizedKeys = {
    'audio',
    'rawaudio',
    'audiobytes',
    'audioblob',
    'audiobase64',
    'audiodata',
    'audiosamples',
    'microphonebuffer',
    'recording',
    'recordingbytes',
    'recordingdata',
    'transcript',
    'recognizedtext',
    'recognizedwords',
    'spokenwords',
    'utterance',
    'speechtext',
  };

  static Map<String, dynamic> sanitize(Map<String, Object?> metadata) {
    final sanitized = <String, dynamic>{};
    for (final entry in metadata.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || _isBlockedKey(key)) {
        continue;
      }

      final value = _sanitizeValue(entry.value);
      if (value != null) {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }

  static bool _isBlockedKey(String key) {
    final normalized = key
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toLowerCase();
    return _blockedNormalizedKeys.contains(normalized);
  }

  static dynamic _sanitizeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Uri) {
      return value.toString();
    }
    if (value is ByteBuffer || value is TypedData) {
      return null;
    }
    if (value is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty || _isBlockedKey(key)) {
          continue;
        }
        final childValue = _sanitizeValue(entry.value as Object?);
        if (childValue != null) {
          sanitized[key] = childValue;
        }
      }
      return sanitized;
    }
    if (value is Iterable) {
      return value
          .map((item) => _sanitizeValue(item as Object?))
          .where((item) => item != null)
          .toList(growable: false);
    }

    return value.toString();
  }
}

abstract interface class AnalyticsTransport {
  Future<void> send(Map<String, dynamic> body, {String? accessToken});
}

class HttpAnalyticsTransport implements AnalyticsTransport {
  HttpAnalyticsTransport({
    required http.Client client,
    required String apiBaseUrl,
  }) : _client = client,
       _endpoint = _analyticsEndpoint(apiBaseUrl);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<void> send(Map<String, dynamic> body, {String? accessToken}) async {
    final headers = <String, String>{
      'accept': 'application/json',
      'content-type': 'application/json',
      if (accessToken != null && accessToken.trim().isNotEmpty)
        'authorization': 'Bearer $accessToken',
    };

    final response = await _client.post(
      _endpoint,
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnalyticsTransportException(
        'Analytics request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }

  static Uri _analyticsEndpoint(String apiBaseUrl) {
    final trimmed = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final base = trimmed.isEmpty ? 'https://storia.kids' : trimmed;
    return Uri.parse('$base/api/analytics/events');
  }
}

class AnalyticsTransportException implements Exception {
  const AnalyticsTransportException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AnalyticsRepository {
  AnalyticsRepository({
    required AnalyticsTransport transport,
    AnalyticsClock? clock,
    AnalyticsStringResolver? currentUserId,
    AnalyticsStringResolver? currentAccessToken,
    AnalyticsStringResolver? currentChildProfileId,
    AnalyticsStringResolver? currentAnonId,
  }) : _transport = transport,
       _clock = clock ?? DateTime.now,
       _currentUserId = currentUserId ?? _nullString,
       _currentAccessToken = currentAccessToken ?? _nullString,
       _currentChildProfileId = currentChildProfileId ?? _nullString,
       _currentAnonId = currentAnonId ?? _nullString;

  final AnalyticsTransport _transport;
  final AnalyticsClock _clock;
  final AnalyticsStringResolver _currentUserId;
  final AnalyticsStringResolver _currentAccessToken;
  final AnalyticsStringResolver _currentChildProfileId;
  final AnalyticsStringResolver _currentAnonId;

  /// What storia's events route accepts from a reader with no account
  /// (`GUEST_EVENTS` in storia `src/app/api/analytics/events/route.ts`).
  static const Set<AnalyticsEventType> guestEvents = {
    AnalyticsEventType.readingSessionStarted,
    AnalyticsEventType.readingSessionEnded,
    AnalyticsEventType.bookStarted,
    AnalyticsEventType.pageViewed,
    AnalyticsEventType.bookCompleted,
  };

  Future<bool> track(
    AnalyticsEventType type, {
    String? childProfileId,
    String? userId,
    String? bookId,
    String? pageId,
    int? pageNumber,
    String? sessionId,
    AnalyticsMetadata metadata = const {},
    DateTime? occurredAt,
  }) async {
    try {
      return await trackEvent(
        AnalyticsEvent(
          type: type,
          occurredAt: occurredAt ?? _clock(),
          userId: userId,
          childProfileId: childProfileId,
          bookId: bookId,
          pageId: pageId,
          pageNumber: pageNumber,
          sessionId: sessionId,
          metadata: metadata,
        ),
      );
    } catch (error, stackTrace) {
      _logNonFatal('Failed to track ${type.eventName}: $error', stackTrace);
      return false;
    }
  }

  /// Sends an analytics event. Returns false on analytics pipeline failures
  /// and never throws, so instrumentation is non-fatal for reader flows.
  /// Events without a child profile (sign-up, onboarding, app open) are sent
  /// against the signed-in user only. Signed out, reader events carry the
  /// device's anonymous id instead; everything else is dropped.
  Future<bool> trackEvent(AnalyticsEvent event) async {
    try {
      final accessToken = _currentAccessToken();
      final anonId = _currentAnonId();
      if (anonId != null &&
          (accessToken == null || accessToken.trim().isEmpty)) {
        if (!guestEvents.contains(event.type)) return false;
        await _transport.send({...event.toApiJson(), 'anonId': anonId});
        return true;
      }

      final childProfileId = _firstNonBlank(
        event.childProfileId,
        _currentChildProfileId(),
      );

      final eventWithContext = event.copyWith(
        childProfileId: childProfileId,
        userId: _firstNonBlank(event.userId, _currentUserId()),
      );

      await _transport.send(
        eventWithContext.toApiJson(childProfileId: childProfileId),
        accessToken: accessToken,
      );
      return true;
    } catch (error, stackTrace) {
      _logNonFatal(
        'Failed to track ${event.type.eventName}: $error',
        stackTrace,
      );
      return false;
    }
  }

  static String? _nullString() => null;

  static String? _firstNonBlank(String? first, String? second) {
    if (first != null && first.trim().isNotEmpty) {
      return first;
    }
    if (second != null && second.trim().isNotEmpty) {
      return second;
    }
    return null;
  }

  void _logNonFatal(String message, [StackTrace? stackTrace]) {
    assert(() {
      debugPrint('[AnalyticsRepository] $message');
      return true;
    }());
  }
}

/// Random UUID v4 kept per install (per browser on web), so signed-out reading
/// counts as one reader. Same idea as the storia web reader's `storia_anon_id`.
Future<String?> loadAnonId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('storia_anon_id');
    if (existing != null) return existing;
    final random = Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
    await prefs.setString('storia_anon_id', id);
    return id;
  } catch (_) {
    return null; // Analytics must never block launch.
  }
}

bool _isPositiveIntegerString(String? value) {
  if (value == null) {
    return false;
  }
  final trimmed = value.trim();
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
    return false;
  }
  return trimmed.contains(RegExp(r'[1-9]'));
}
