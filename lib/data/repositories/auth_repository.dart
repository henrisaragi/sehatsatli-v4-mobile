import 'dart:convert';

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

class OtpResult {
  OtpResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class AuthRepository {
  AuthRepository({ApiClient? apiClient, SecureStorage? secureStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorage();

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  Future<AuthResult> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.loginApp,
      body: {
        'email': email,
        'password': password,
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

  /// Step 1 of the guest OTP reset flow (docs/reset-password.md) — emails a
  /// one-time code to [email]. Unauthenticated, no token.
  Future<OtpResult> requestPasswordOtp(String email) async {
    final response = await _apiClient.post(
      ApiEndpoints.passwordOtpRequest,
      body: {'email': email},
    );
    if (!isApiSuccess(response)) {
      return OtpResult(success: false, message: extractApiMessage(response));
    }
    return OtpResult(success: true);
  }

  /// Step 2 — verifies the OTP emailed in [requestPasswordOtp] before the
  /// user is allowed to set a new password.
  Future<OtpResult> verifyPasswordOtp(String email, String otp) async {
    final response = await _apiClient.post(
      ApiEndpoints.passwordOtpVerify,
      body: {'email': email, 'otp': otp},
    );
    if (!isApiSuccess(response)) {
      return OtpResult(success: false, message: extractApiMessage(response));
    }
    return OtpResult(success: true);
  }

  /// Step 3 — sets the new password using the same verified [email]/[otp]
  /// pair.
  Future<OtpResult> resetPasswordWithOtp(
    String email,
    String otp,
    String password,
    String passwordConfirmation,
  ) async {
    final response = await _apiClient.post(
      ApiEndpoints.passwordOtpReset,
      body: {
        'email': email,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    if (!isApiSuccess(response)) {
      return OtpResult(success: false, message: extractApiMessage(response));
    }
    return OtpResult(success: true);
  }
}
