import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';

class CommunityReportSubmitResult {
  CommunityReportSubmitResult({required this.success, this.message});

  final bool success;
  final String? message;
}

/// One row from `community-reports/getAll` (API_ENDPOINTS.md §4). A
/// community report starts as an informal tip from the public and can later
/// be "promoted" by an officer into an official `GeneralReportSource` — the
/// `laporan`/`id_laporan` relation (best-effort key names, unconfirmed
/// against a live response) is how that's surfaced here as [promoted].
class CommunityReportSummary {
  CommunityReportSummary({
    required this.id,
    required this.name,
    required this.reportDate,
    required this.description,
    required this.promoted,
    required this.raw,
  });

  factory CommunityReportSummary.fromJson(Map<String, dynamic> json) {
    return CommunityReportSummary(
      id: json['id'],
      name: (json['name'] ?? '-').toString(),
      reportDate: (json['report_date'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      promoted: json['laporan'] != null || json['id_laporan'] != null,
      raw: json,
    );
  }

  final dynamic id;
  final String name;
  final String reportDate;
  final String description;
  final bool promoted;
  final Map<String, dynamic> raw;
}

class CommunityReportRepository {
  CommunityReportRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Public endpoint, deliberately called with no token — this is the
  /// "kirim laporan cepat tanpa akun" flow for members of the public.
  Future<CommunityReportSubmitResult> save({
    required String name,
    required DateTime reportDate,
    required String description,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.communityReportsSave,
      body: {
        'name': name,
        'report_date': reportDate.toIso8601String().split('T').first,
        'description': description,
      },
    );

    if (!isApiSuccess(response)) {
      return CommunityReportSubmitResult(
        success: false,
        message: extractApiMessage(response) ?? 'Gagal mengirim laporan',
      );
    }
    return CommunityReportSubmitResult(success: true);
  }

  /// Technically a public endpoint per API_ENDPOINTS.md §4, but this app
  /// only surfaces it inside the logged-in officer's "Laporan Masyarakat"
  /// list, so a token is passed along when available.
  Future<List<CommunityReportSummary>> fetchAll({String? token}) async {
    final response =
        await _apiClient.post(ApiEndpoints.communityReportsGetAll, token: token);
    if (!isApiSuccess(response)) return [];

    final data = response['data'];
    List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map && data['data'] is List) {
      items = data['data'] as List;
    } else {
      items = const [];
    }

    return items
        .whereType<Map>()
        .map((e) => CommunityReportSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchOne({
    required dynamic id,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.communityReportsGetOne,
      body: {'id': id},
      token: token,
    );
    if (!isApiSuccess(response)) return null;
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }
}
