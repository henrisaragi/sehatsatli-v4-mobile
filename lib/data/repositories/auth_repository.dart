import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';
import '../../core/storage/secure_storage.dart';

class AuthResult {
  AuthResult({
    required this.success,
    this.token,
    this.user,
    this.message,
  });

  final bool success;
  final String? token;
  final dynamic user;
  final String? message;
}

class AuthRepository {
  AuthRepository({ApiClient? apiClient, SecureStorage? secureStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorage();

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  String _md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

  Future<AuthResult> login(String email, String password) async {
    // Confirmed against the live API: despite CLAUDE.md §6.1 describing
    // `username` for email and `username1` for phone, the server actually
    // expects the email hash under `username1`.
    final response = await _apiClient.post(
      ApiEndpoints.loginApp,
      body: {
        'username1': _md5Hex(email),
        'password': _md5Hex(password),
      },
    );

    if (!isApiSuccess(response)) {
      return AuthResult(success: false, message: extractApiMessage(response));
    }

    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    final token = data['access_token'] ?? response['access_token'] ?? data['token'];
    final user = data['user'] ?? response['user'];

    if (token is String) {
      await _secureStorage.saveToken(token);
    }
    if (user is Map) {
      await _secureStorage.saveUserJson(jsonEncode(user));
    }

    return AuthResult(
      success: true,
      token: token is String ? token : null,
      user: user,
    );
  }

  /// Reads the persisted token, if any — used on cold start to decide
  /// whether to skip the login screen.
  Future<String?> readPersistedToken() => _secureStorage.readToken();

  /// Reads the persisted login-response user object, if any — used on cold
  /// start alongside [readPersistedToken] to restore `FFAppState.currentUser`
  /// (and with it the RBAC flags derived from it) without a network call.
  Future<dynamic> readPersistedUser() async {
    final json = await _secureStorage.readUserJson();
    if (json == null) return null;
    try {
      return jsonDecode(json);
    } catch (_) {
      return null;
    }
  }

  /// Overwrites the persisted user snapshot — used after a profile mutation
  /// (e.g. photo upload) whose response includes an updated user object, so
  /// the change survives an app restart instead of only living in
  /// `FFAppState.currentUser` for the rest of the session.
  Future<void> updatePersistedUser(Map<String, dynamic> user) =>
      _secureStorage.saveUserJson(jsonEncode(user));

  /// Revokes the token server-side (also clears the FCM device token per
  /// API_ENDPOINTS.md §1) and always clears the local session regardless of
  /// whether the network call succeeds.
  Future<void> logout() async {
    final token = await _secureStorage.readToken();
    if (token != null) {
      try {
        await _apiClient.post(ApiEndpoints.logout, token: token);
      } on ApiNetworkException {
        // Best-effort — still clear the local session below.
      }
    }
    await _secureStorage.deleteToken();
    await _secureStorage.deleteUserJson();
  }

  /// Server endpoint is misleadingly named "forgot-password" but actually
  /// changes the password of the currently-logged-in user (API_ENDPOINTS.md §1).
  Future<AuthResult> changePassword(String newPassword) async {
    final token = await _secureStorage.readToken();
    final response = await _apiClient.post(
      ApiEndpoints.changePassword,
      token: token,
      body: {'password': newPassword},
    );

    if (!isApiSuccess(response)) {
      return AuthResult(success: false, message: extractApiMessage(response));
    }
    return AuthResult(success: true);
  }
}
