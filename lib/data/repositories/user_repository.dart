import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';

class UploadPhotoResult {
  UploadPhotoResult({required this.success, this.user, this.message});

  final bool success;
  final Map<String, dynamic>? user;
  final String? message;
}

class SaveProfileResult {
  SaveProfileResult({required this.success, this.user, this.message});

  final bool success;
  final Map<String, dynamic>? user;
  final String? message;
}

class UserRepository {
  UserRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Detail for one user (API_ENDPOINTS.md §5). Used to refresh the
  /// profile page against the server instead of only the stale
  /// login-response snapshot in `FFAppState().currentUser`.
  Future<Map<String, dynamic>?> fetchOne({
    required dynamic id,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.usersGetOne,
      body: {'id': id},
      token: token,
    );
    if (!isApiSuccess(response)) return null;
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  /// Uploads a profile photo as a base64 data URI (mobile variant — not
  /// multipart, see API_ENDPOINTS.md §5). Response shape for the updated
  /// user object isn't confirmed against a live response, so [user] is
  /// best-effort and callers should keep their own local preview as the
  /// source of truth for this session.
  Future<UploadPhotoResult> uploadPhoto({
    required dynamic id,
    required String base64File,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.usersUploadPhotoMobile,
      body: {'id': id, 'file': base64File},
      token: token,
    );
    if (!isApiSuccess(response)) {
      return UploadPhotoResult(
        success: false,
        message: extractApiMessage(response) ?? 'Gagal mengunggah foto',
      );
    }
    final data = response['data'];
    return UploadPhotoResult(
      success: true,
      user: data is Map<String, dynamic> ? data : null,
    );
  }

  /// Saves the officer's own profile (docs/update-profile.md) — a distinct,
  /// newer endpoint from the documented-broken `/update-user` in
  /// API_ENDPOINTS.md §5 (that one always no-ops server-side). [payload]
  /// should be the full user object (existing fields merged with edits),
  /// since this looks like a full save rather than a partial patch.
  Future<SaveProfileResult> saveProfile({
    required Map<String, dynamic> payload,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.usersSave,
      body: payload,
      token: token,
    );
    if (!isApiSuccess(response)) {
      return SaveProfileResult(
        success: false,
        message: extractApiMessage(response) ?? 'Gagal menyimpan profil',
      );
    }
    final data = response['data'];
    return SaveProfileResult(
      success: true,
      user: data is Map<String, dynamic> ? data : null,
    );
  }
}
