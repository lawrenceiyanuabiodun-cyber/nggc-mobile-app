import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// ─────────────────────────────────────────────────────────
/// ApiService
/// Core HTTP client for all backend calls to Render.
/// - Auto-injects JWT tokens
/// - Handles timeouts (60s for Render wake-up)
/// - Parses JSON responses
/// - Provides clean error handling
/// ─────────────────────────────────────────────────────────
class ApiService {
  ApiService._();

  static const _storage = FlutterSecureStorage();

  /// ── Base URLs ──────────────────────────────────────────
  static String get baseUrl => AppConfig.baseUrl;
  static String get apiUrl => AppConfig.apiUrl;

  /// ── Token Management ──────────────────────────────────
  static Future<String?> getToken() async {
    return await _storage.read(key: AppConfig.tokenStorageKey);
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: AppConfig.tokenStorageKey, value: token);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: AppConfig.tokenStorageKey);
  }

  /// ── Headers ───────────────────────────────────────────
  static Future<Map<String, String>> _getHeaders({
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// ── GET Request ───────────────────────────────────────
  static Future<ApiResponse> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final headers = await _getHeaders(includeAuth: requireAuth);

      if (kDebugMode) print('🌐 GET: $uri');

      final response = await http
          .get(uri, headers: headers)
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error(
        'Request timed out. Server may be waking up, please try again.',
        statusCode: 408,
      );
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// ── POST Request ──────────────────────────────────────
  static Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, null);
      final headers = await _getHeaders(includeAuth: requireAuth);

      if (kDebugMode) print('🌐 POST: $uri');

      final response = await http
          .post(uri, headers: headers, body: json.encode(body ?? {}))
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error(
        'Request timed out. Server may be waking up, please try again.',
        statusCode: 408,
      );
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// ── PUT Request ───────────────────────────────────────
  static Future<ApiResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, null);
      final headers = await _getHeaders(includeAuth: requireAuth);

      if (kDebugMode) print('🌐 PUT: $uri');

      final response = await http
          .put(uri, headers: headers, body: json.encode(body ?? {}))
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error(
        'Request timed out. Server may be waking up, please try again.',
        statusCode: 408,
      );
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// ── PATCH Request ─────────────────────────────────────
  static Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, null);
      final headers = await _getHeaders(includeAuth: requireAuth);

      if (kDebugMode) print('🌐 PATCH: $uri');

      final response = await http
          .patch(uri, headers: headers, body: json.encode(body ?? {}))
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error(
        'Request timed out. Server may be waking up, please try again.',
        statusCode: 408,
      );
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// ── DELETE Request ────────────────────────────────────
  static Future<ApiResponse> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    try {
      final uri = _buildUri(endpoint, null);
      final headers = await _getHeaders(includeAuth: requireAuth);

      if (kDebugMode) print('🌐 DELETE: $uri');

      final response = await http
          .delete(uri, headers: headers)
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResponse.error(
        'Request timed out. Server may be waking up, please try again.',
        statusCode: 408,
      );
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// ── URI Builder ───────────────────────────────────────
  static Uri _buildUri(String endpoint, Map<String, dynamic>? queryParams) {
    // Endpoint can be full URL or path-only
    String fullPath;
    if (endpoint.startsWith('http')) {
      fullPath = endpoint;
    } else if (endpoint.startsWith('/')) {
      fullPath = '$baseUrl$endpoint';
    } else {
      fullPath = '$baseUrl/$endpoint';
    }

    final uri = Uri.parse(fullPath);
    if (queryParams == null || queryParams.isEmpty) return uri;

    return uri.replace(
      queryParameters: queryParams.map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      ),
    );
  }

  /// ── Response Handler ──────────────────────────────────
  static ApiResponse _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic body;

    try {
      body = json.decode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = response.body;
    }

    if (kDebugMode) {
      print('📡 Response [$statusCode]: ${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}');
    }

    if (statusCode >= 200 && statusCode < 300) {
      return ApiResponse.success(body, statusCode: statusCode);
    }

    // Extract error message from response
    String errorMsg = 'Request failed';
    if (body is Map) {
      errorMsg = body['detail']?.toString() ??
          body['message']?.toString() ??
          body['error']?.toString() ??
          'Request failed with status $statusCode';
    }

    return ApiResponse.error(errorMsg, statusCode: statusCode, data: body);
  }
}

/// ─────────────────────────────────────────────────────────
/// ApiResponse
/// Wrapper for HTTP responses with success/error state
/// ─────────────────────────────────────────────────────────
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int? statusCode;

  ApiResponse._({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.success(dynamic data, {int? statusCode}) {
    return ApiResponse._(
      success: true,
      data: data,
      statusCode: statusCode,
    );
  }

  factory ApiResponse.error(String message, {int? statusCode, dynamic data}) {
    return ApiResponse._(
      success: false,
      error: message,
      statusCode: statusCode,
      data: data,
    );
  }

  bool get isSuccess => success;
  bool get isError => !success;

  /// Get data as Map safely
  Map<String, dynamic>? get asMap {
    if (data is Map<String, dynamic>) return data as Map<String, dynamic>;
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    return null;
  }

  /// Get data as List safely
  List<dynamic>? get asList {
    if (data is List) return data as List;
    return null;
  }
}
