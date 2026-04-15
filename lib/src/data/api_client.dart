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
  const ApiClient(this._supabase);

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

  Future<dynamic> _request(
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

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      ..._authHeaders(),
    };

    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      default:
        throw ApiClientException(message: 'Unsupported method: $method');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiClientException(
        message: 'Request failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }

  Map<String, String> _authHeaders() {
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      return const {};
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'X-Supabase-Access-Token': accessToken,
    };
  }
}
