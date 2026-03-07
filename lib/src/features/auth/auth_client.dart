import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String? image;

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String,
        image: json['image'] as String?,
      );
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthException: $message';
}

class BetterAuthClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'auth_token';

  BetterAuthClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    final baseUrl =
        dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  Future<void> sendOtp(String email) async {
    try {
      await _dio.post(
        '/api/auth/email-otp/send-verification-otp',
        data: {'email': email, 'type': 'sign-in'},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthUser> verifyOtp(String email, String otp) async {
    try {
      final response = await _dio.post(
        '/api/auth/sign-in/email-otp',
        data: {'email': email, 'otp': otp},
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null) {
        throw AuthException('No token received from server');
      }

      await _storage.write(key: _tokenKey, value: token);

      final userJson = data['user'] as Map<String, dynamic>;
      return AuthUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthUser?> getSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;

    try {
      final response = await _dio.get('/api/auth/get-session');
      final data = response.data as Map<String, dynamic>;

      if (data['user'] == null) {
        await _storage.delete(key: _tokenKey);
        return null;
      }

      final userJson = data['user'] as Map<String, dynamic>;
      return AuthUser.fromJson(userJson);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        return null;
      }
      throw _handleError(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _dio.post('/api/auth/sign-out');
    } on DioException catch (_) {
      // Sign out even if the server request fails
    } finally {
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<AuthUser> updateUser({String? name, String? image}) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (image != null) data['image'] = image;

      final response = await _dio.post(
        '/api/auth/update-user',
        data: data,
      );

      final responseData = response.data as Map<String, dynamic>;
      final userJson = responseData['user'] as Map<String, dynamic>;
      return AuthUser.fromJson(userJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null;
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  AuthException _handleError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    String message;
    if (data is Map<String, dynamic> && data.containsKey('message')) {
      message = data['message'] as String;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Please try again.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Could not connect to server. Please check your connection.';
    } else {
      message = 'Something went wrong. Please try again.';
    }

    return AuthException(message, statusCode: statusCode);
  }
}
