import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

/// Result of `POST /api/registrasi/upt` (docs-new-versions/register-upt.md).
class RegistrationSubmitResult {
  RegistrationSubmitResult({
    required this.success,
    this.message,
    this.fieldErrors = const {},
  });

  final bool success;
  final String? message;

  /// Field name -> first validation message, from the 422 `errors` map.
  final Map<String, String> fieldErrors;
}

/// Guest (no-token) UPT self-registration —
/// docs-new-versions/register-upt.md. Distinct from [AuthRepository] since
/// none of these calls carry a session.
class RegistrationRepository {
  RegistrationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// `GET /api/upt` — bare JSON array; optionally filtered by
  /// `kategori` ('TAMAN_NASIONAL' | 'KSDA').
  Future<List<Map<String, dynamic>>> fetchUptList({String? kategori}) async {
    final path = kategori == null || kategori.isEmpty
        ? ApiEndpoints.uptGetAll
        : '${ApiEndpoints.uptGetAll}?kategori=${Uri.encodeQueryComponent(kategori)}';
    final response = await _apiClient.get(path);
    return _asMapList(response['data']);
  }

  /// `GET /api/upt/{upt_id}/unit-organisasi` — flat list, ordered by
  /// `level`/`parent_id`. A 404 (invalid `upt_id`) decodes to a `message`
  /// body with no list, so this just comes back empty.
  Future<List<Map<String, dynamic>>> fetchUnitOrganisasi(String uptId) async {
    final response =
        await _apiClient.get(ApiEndpoints.uptUnitOrganisasi(uptId));
    return _asMapList(response['data']);
  }

  /// `POST /api/registrasi/upt`.
  Future<RegistrationSubmitResult> submitRegistration({
    required String nama,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String uptId,
    required String unitOrganisasiId,
    required String nip,
    required String jabatan,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.registrasiUpt,
      body: {
        'nama': nama,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'upt_id': uptId,
        'unit_organisasi_id': unitOrganisasiId,
        'nip': nip,
        'jabatan': jabatan,
      },
    );

    if (response['user_id'] != null) {
      return RegistrationSubmitResult(success: true);
    }

    final errors = response['errors'];
    final fieldErrors = <String, String>{};
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        fieldErrors[entry.key.toString()] =
            value is List ? value.first.toString() : value.toString();
      }
    }

    final message = response['message'];
    return RegistrationSubmitResult(
      success: false,
      message: message is String ? message : 'Registrasi gagal.',
      fieldErrors: fieldErrors,
    );
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
