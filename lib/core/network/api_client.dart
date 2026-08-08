import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_endpoints.dart';

/// Thrown when the request never reached the server (no connection, DNS
/// failure, timeout) — distinct from the server responding with
/// `success: false`, which callers detect via [isApiSuccess] instead.
class ApiNetworkException implements Exception {
  ApiNetworkException(this.message);

  final String message;

  @override
  String toString() => 'ApiNetworkException: $message';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 15);

  /// Set once from main.dart. Invoked whenever any request comes back with
  /// HTTP 401, so the caller can clear the session and redirect to login.
  static void Function()? onUnauthorized;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$path');
    final headers = _headers(token);

    http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: jsonEncode(body ?? {}))
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiNetworkException('Request to $path timed out');
    } on SocketException catch (e) {
      throw ApiNetworkException('Could not reach server: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiNetworkException('Network error: ${e.message}');
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    String? token,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$path');
    final headers = _headers(token);

    http.Response response;
    try {
      response =
          await _client.get(uri, headers: headers).timeout(timeout ?? _timeout);
    } on TimeoutException {
      throw ApiNetworkException('Request to $path timed out');
    } on SocketException catch (e) {
      throw ApiNetworkException('Could not reach server: ${e.message}');
    } on http.ClientException catch (e) {
      throw ApiNetworkException('Network error: ${e.message}');
    }

    return _handleResponse(response);
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'data': decoded};
  }
}
