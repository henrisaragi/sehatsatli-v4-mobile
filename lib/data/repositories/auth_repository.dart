import 'dart:async';
import 'dart:convert';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/push_service.dart';
import '../../core/storage/secure_storage.dart';

class PasswordResetResult {
  PasswordResetResult({
    required this.success,
    this.resetToken,
    this.message,
    this.tokenInvalid = false,
  });

  final bool success;
  final String? resetToken;
  final String? message;

  /// True when the reset token is expired or out of attempts — restart from
  /// step 1.
  final bool tokenInvalid;
}

/// Step 1 of the v4 login flow (docs-new-versions/login.md) — result of
/// `POST /api/auth/login`. Success carries a short-lived `login_token` (not
/// an access token) to be exchanged for one in step 2.
class LoginOtpRequestResult {
  LoginOtpRequestResult({
    required this.success,
    this.loginToken,
    this.expiresIn,
    this.message,
  });

  final bool success;
  final String? loginToken;
  final int? expiresIn;
  final String? message;
}

/// Step 2 — result of `POST /api/auth/otp/verify`.
class LoginOtpVerifyResult {
  LoginOtpVerifyResult({
    required this.success,
    this.accessToken,
    this.message,
    this.attemptsRemaining,
    this.tokenInvalid = false,
  });

  final bool success;
  final String? accessToken;
  final String? message;

  /// Present only for the "wrong OTP, try again" case.
  final int? attemptsRemaining;

  /// True when the `login_token` itself is dead (expired or max attempts
  /// reached) — there's no resend, caller must restart from step 1.
  final bool tokenInvalid;
}

/// Result of `GET /api/registrasi/status` — used right after login to route
/// the user (docs-new-versions/login.md + register-upt.md).
class RegistrationStatusResult {
  RegistrationStatusResult({
    required this.exists,
    this.statusVerifikasi,
    this.alasanPenolakan,
    this.upt,
    this.unitOrganisasi,
    this.nip,
    this.jabatan,
  });

  /// False when the user has never submitted a UPT registration (server
  /// responds 404).
  final bool exists;

  /// 'menunggu' | 'ditolak' | 'terverifikasi'
  final String? statusVerifikasi;
  final String? alasanPenolakan;
  final Map<String, dynamic>? upt;
  final Map<String, dynamic>? unitOrganisasi;
  final String? nip;
  final String? jabatan;
}

class AuthRepository {
  AuthRepository({ApiClient? apiClient, SecureStorage? secureStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorage();

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  /// Step 1 of the v4 login flow — emails an OTP and returns a short-lived
  /// `login_token` to carry into [verifyLoginOtp]. Unlike the old envelope,
  /// v4 success responses have no `success` field at all — they're bare
  /// JSON — so success here is detected by the presence of `login_token`.
  Future<LoginOtpRequestResult> requestLoginOtp(
      String email, String password) async {
    final response = await _apiClient.request(
      'POST',
      ApiEndpoints.authLogin,
      body: {'email': email, 'password': password},
    );

    final loginToken = response.body['login_token'];
    if (response.isSuccess && loginToken is String) {
      final expiresIn = response.body['expires_in'];
      return LoginOtpRequestResult(
        success: true,
        loginToken: loginToken,
        expiresIn: expiresIn is int ? expiresIn : null,
      );
    }
    return LoginOtpRequestResult(
      success: false,
      message: response.statusCode == 401 && response.body['message'] == null
          ? 'Email atau password salah.'
          : response.message,
    );
  }

  /// Step 2 — exchanges the OTP + step-1 `login_token` for a real access
  /// token. Persists it on success, same as the old single-step login did.
  Future<LoginOtpVerifyResult> verifyLoginOtp(
      String loginToken, String otp) async {
    final response = await _apiClient.request(
      'POST',
      ApiEndpoints.authOtpVerify,
      body: {'login_token': loginToken, 'otp': otp},
    );

    final accessToken = response.body['access_token'];
    if (response.isSuccess && accessToken is String) {
      await _secureStorage.saveToken(accessToken);
      return LoginOtpVerifyResult(success: true, accessToken: accessToken);
    }

    final attemptsRemaining = response.body['attempts_remaining'];
    return LoginOtpVerifyResult(
      success: false,
      message: response.message,
      attemptsRemaining: attemptsRemaining is int ? attemptsRemaining : null,
      // A server hiccup says nothing about the login token — keep it.
      tokenInvalid: !response.isTransient && attemptsRemaining is! int,
    );
  }

  /// `GET /api/user` — the response body *is* the user object (no `data`
  /// wrapper). Used right after OTP verification since step 2's response
  /// carries only the token, not a user snapshot.
  Future<Map<String, dynamic>?> fetchCurrentUser(String token) async {
    final response = await _apiClient.get(ApiEndpoints.userMe, token: token);
    if (response['id'] == null) return null;
    await _secureStorage.saveUserJson(jsonEncode(response));
    return response;
  }

  /// `GET /api/registrasi/status` — a 404 body (`{"message": "..."}`, no
  /// `status_verifikasi`) means the user never registered as UPT staff.
  Future<RegistrationStatusResult> fetchRegistrationStatus(
      String token) async {
    final response =
        await _apiClient.get(ApiEndpoints.registrasiStatus, token: token);
    final status = response['status_verifikasi'];
    if (status is! String) {
      return RegistrationStatusResult(exists: false);
    }
    return RegistrationStatusResult(
      exists: true,
      statusVerifikasi: status,
      alasanPenolakan: response['alasan_penolakan'] as String?,
      upt: response['upt'] is Map
          ? Map<String, dynamic>.from(response['upt'] as Map)
          : null,
      unitOrganisasi: response['unit_organisasi'] is Map
          ? Map<String, dynamic>.from(response['unit_organisasi'] as Map)
          : null,
      nip: response['nip'] as String?,
      jabatan: response['jabatan'] as String?,
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

  /// Clears the persisted session right away, then revokes the token on the
  /// server in the background (`POST auth/logout`), so logout is instant even
  /// offline or on a slow server. Never touches `local_reports` or
  /// `sync_queue` — unsynced field data survives a logout (CLAUDE.md §10.5).
  Future<void> logout() async {
    final token = await _secureStorage.readToken();
    await _secureStorage.deleteToken();
    await _secureStorage.deleteUserJson();
    if (token != null) unawaited(_revokeToken(token));
  }

  Future<void> _revokeToken(String token) async {
    // Must run before the token is revoked: it authenticates the request.
    await PushService.instance.unregisterForUser(token);
    try {
      // A 401 here only means the old token is already dead — it must not
      // trigger the global session handler, which could log out a session
      // started meanwhile.
      await _apiClient.request('POST', ApiEndpoints.authLogout,
          token: token, reportUnauthorized: false, timeout: const Duration(seconds: 10));
    } catch (_) {
      // Best-effort; the local session is already gone.
    }
  }

  /// Step 1 of the guest reset flow (docs-new-versions/forgot-password.md) —
  /// emails an OTP and returns a `reset_token` (valid 5 minutes) that steps
  /// 2 and 3 carry.
  Future<PasswordResetResult> requestPasswordOtp(String email) async {
    final response = await _apiClient.request(
      'POST',
      ApiEndpoints.passwordOtpRequest,
      body: {'email': email},
    );
    final resetToken = response.body['reset_token'];
    if (response.isSuccess && resetToken is String) {
      return PasswordResetResult(success: true, resetToken: resetToken);
    }
    return PasswordResetResult(success: false, message: response.message);
  }

  /// Step 2 — checks the OTP against [resetToken]. On a wrong code the server
  /// answers 422 with `attempts_remaining`; without it the token is dead and
  /// the user must restart from step 1.
  Future<PasswordResetResult> verifyPasswordOtp(String resetToken, String otp) async {
    final response = await _apiClient.request(
      'POST',
      ApiEndpoints.passwordOtpVerify,
      body: {'reset_token': resetToken, 'otp': otp},
    );
    if (response.isSuccess) {
      return PasswordResetResult(success: true, resetToken: resetToken);
    }
    return PasswordResetResult(
      success: false,
      message: response.message,
      tokenInvalid: response.body['attempts_remaining'] is! int,
    );
  }

  /// Step 3 — sets the new password with the verified [resetToken]. The
  /// server revokes every existing access token of the user.
  Future<PasswordResetResult> resetPasswordWithOtp(
    String resetToken,
    String password,
    String passwordConfirmation,
  ) async {
    final response = await _apiClient.request(
      'POST',
      ApiEndpoints.passwordOtpReset,
      body: {
        'reset_token': resetToken,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return response.isSuccess
        ? PasswordResetResult(success: true)
        : PasswordResetResult(success: false, message: response.message);
  }
}
