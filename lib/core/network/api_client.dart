import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';
import 'api_error_text.dart';

/// Thrown when the request never reached the server (no connection, DNS
/// failure, timeout) — distinct from the server answering with an error
/// status, which comes back as an [ApiResponse].
class ApiNetworkException implements Exception {
  ApiNetworkException(this.message);

  final String message;

  @override
  String toString() => 'ApiNetworkException: $message';
}

/// Thrown when the server responds 429 (rate limited) — e.g. the `auth/*`
/// group's 6 requests/minute throttle.
class ApiRateLimitException implements Exception {
  ApiRateLimitException([this.message]);

  final String? message;

  @override
  String toString() => 'ApiRateLimitException: $message';
}

/// A server answer. Backend v4 uses real HTTP status codes (2xx success,
/// 401/403/404/422 client errors) and bare JSON bodies — no `success` field.
class ApiResponse {
  ApiResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Worth retrying later without changing the request (server hiccup,
  /// gateway timeout) — as opposed to a 4xx the request itself caused.
  bool get isTransient => statusCode >= 500 || statusCode == 408;

  /// One user-facing line (or one line per invalid field) for a failed
  /// answer: Laravel's `{message, errors: {field: [..]}}` reworded in
  /// Indonesian with field labels, and generic text for 5xx/403/404 instead
  /// of Laravel's bare "Server Error".
  String get message {
    if (statusCode >= 500) return serverErrorText(statusCode);
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      return errors.entries.map((e) {
        final first = e.value is List && (e.value as List).isNotEmpty
            ? (e.value as List).first.toString()
            : e.value.toString();
        return '${fieldLabel(e.key.toString())}: ${translateValidation(first)}';
      }).join('\n');
    }
    final message = body['message'];
    final generic = message is! String ||
        message.isEmpty ||
        message == 'This action is unauthorized.' ||
        message == 'Not Found' ||
        message.startsWith('No query results for model');
    if (!generic) return message;
    if (statusCode == 403) return 'Anda tidak memiliki akses untuk tindakan ini.';
    if (statusCode == 404) return 'Data tidak ditemukan di server.';
    return 'Server menolak permintaan (HTTP $statusCode).';
  }
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Generous on purpose: field connections are slow, and production's
  // `auth/login` only answers after sending the OTP email (~15s+ measured).
  static const Duration _timeout = Duration(seconds: 30);

  /// Set once from main.dart. Invoked whenever an authenticated request comes
  /// back with HTTP 401, so the app can clear the session and go to login.
  static void Function()? onUnauthorized;

  Future<ApiResponse> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    String? token,
    Duration? timeout,
    bool reportUnauthorized = true,
  }) async {
    var uri = Uri.parse('${ApiEndpoints.baseUrl}$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
      );
    }
    final request = http.Request(method, uri)..headers.addAll(_headers(token));
    if (body != null) request.body = jsonEncode(body);

    final response = await _send(request, timeout ?? _timeout, path);
    return _toApiResponse(response, hadToken: token != null && reportUnauthorized);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async =>
      (await request('POST', path, body: body ?? {}, token: token)).body;

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Duration? timeout,
  }) async =>
      (await request('GET', path, token: token, timeout: timeout)).body;

  /// Raw-body PUT to an absolute presigned object-storage URL (not the API).
  /// Returns the HTTP status code; network failures throw
  /// [ApiNetworkException] like every other call.
  Future<int> putBytes(
    String url,
    List<int> bytes, {
    Map<String, String> headers = const {},
  }) async {
    final request = http.Request('PUT', Uri.parse(url))
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
    final response =
        await _send(request, const Duration(seconds: 60), 'object storage');
    return response.statusCode;
  }

  /// True when the server answers at all (any HTTP status).
  Future<bool> isReachable() async {
    try {
      final request = http.Request('GET', Uri.parse(ApiEndpoints.healthUrl));
      await _send(request, const Duration(seconds: 5), 'up');
      return true;
    } on ApiNetworkException {
      return false;
    }
  }

  Future<http.Response> _send(
    http.BaseRequest request,
    Duration timeout,
    String label,
  ) async {
    try {
      final streamed = await _client.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw ApiNetworkException('Request to $label timed out');
    } on SocketException catch (e) {
      throw ApiNetworkException('Could not reach server: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiNetworkException('Network error: ${e.message}');
    }
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  ApiResponse _toApiResponse(http.Response response, {required bool hadToken}) {
    if (response.statusCode == 429) {
      throw ApiRateLimitException();
    }

    // A 401 on a token-less request (e.g. wrong password at login) is an
    // expected failure the caller handles inline — only a 401 on an
    // authenticated request means the session itself was rejected.
    if (response.statusCode == 401 && hadToken) {
      onUnauthorized?.call();
    }

    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        body = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      } on FormatException {
        body = {};
      }
    }
    return ApiResponse(response.statusCode, body);
  }
}
