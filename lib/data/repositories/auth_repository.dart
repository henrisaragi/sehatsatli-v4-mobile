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
    final response = await _apiClient.post(
      ApiEndpoints.authLogin,
      body: {'email': email, 'password': password},
    );

    final loginToken = response['login_token'];
    if (loginToken is String) {
      final expiresIn = response['expires_in'];
      return LoginOtpRequestResult(
        success: true,
        loginToken: loginToken,
        expiresIn: expiresIn is int ? expiresIn : null,
      );
    }
    return LoginOtpRequestResult(
      success: false,
      message: extractApiMessage(response) ?? 'Email atau password salah.',
    );
  }

  /// Step 2 — exchanges the OTP + step-1 `login_token` for a real access
  /// token. Persists it on success, same as the old single-step login did.
  Future<LoginOtpVerifyResult> verifyLoginOtp(
      String loginToken, String otp) async {
    final response = await _apiClient.post(
      ApiEndpoints.authOtpVerify,
      body: {'login_token': loginToken, 'otp': otp},
    );

    final accessToken = response['access_token'];
    if (accessToken is String) {
      await _secureStorage.saveToken(accessToken);
      return LoginOtpVerifyResult(success: true, accessToken: accessToken);
    }

    final attemptsRemaining = response['attempts_remaining'];
    return LoginOtpVerifyResult(
      success: false,
      message: extractApiMessage(response) ?? 'Gagal memverifikasi OTP.',
      attemptsRemaining: attemptsRemaining is int ? attemptsRemaining : null,
      tokenInvalid: attemptsRemaining is! int,
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
