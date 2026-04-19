import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiClientException implements Exception {
  const ApiClientException({
    required this.message,
    this.statusCode,
    this.body,
  });

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() =>
      'ApiClientException(statusCode: $statusCode, message: $message, body: $body)';
}

class ApiClient {
  ApiClient(this._supabase);

  final SupabaseClient _supabase;

  String get _baseUrl => dotenv.env['API_BASE_URL']?.trim() ?? '';

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    return _request(
      'GET',
      path,
      queryParameters: queryParameters,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    return _request(
      'POST',
      path,
      body: body,
      queryParameters: queryParameters,
    );
  }

  Future<String> getText(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _requestResponse(
      'GET',
      path,
      queryParameters: queryParameters,
    );
    return response.body;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final response = await _requestResponse(
      method,
      path,
      body: body,
      queryParameters: queryParameters,
    );

    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }

  Future<http.Response> _requestResponse(
    String method,
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    if (!isConfigured) {
      throw const ApiClientException(message: 'API_BASE_URL is not configured');
    }

    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );

    var response = await _send(method, uri, body, forceRefresh: false);

    if (response.statusCode == 401) {
      response = await _send(method, uri, body, forceRefresh: true);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        message: 'Request failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    return response;
  }

  Future<http.Response> _send(
    String method,
    Uri uri,
    Object? body, {
    required bool forceRefresh,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ...await _authHeaders(forceRefresh: forceRefresh),
    };

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      default:
        throw ApiClientException(message: 'Unsupported method: $method');
    }
  }

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    var session = _supabase.auth.currentSession;

    final needsRefresh =
        forceRefresh ||
        session == null ||
        (session.expiresAt != null &&
            DateTime.fromMillisecondsSinceEpoch(
              session.expiresAt! * 1000,
            ).isBefore(DateTime.now().add(const Duration(seconds: 30))));

    if (needsRefresh && _supabase.auth.currentUser != null) {
      try {
        final refreshed = await _supabase.auth.refreshSession();
        session = refreshed.session ?? _supabase.auth.currentSession;
      } catch (_) {
        session = _supabase.auth.currentSession;
      }
    }

    final accessToken = session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return const {};
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'X-Supabase-Access-Token': accessToken,
    };
  }
}
