import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';

class DashboardRepository {
  DashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// `dashboard/get-totalLaporan` (API_ENDPOINTS.md §7) has no documented
  /// response sample anywhere, unlike every other endpoint this app calls —
  /// tries a couple of plausible shapes and gives up (returns null) rather
  /// than risk showing a number parsed from the wrong field. Callers should
  /// fall back to a locally-computed estimate when this returns null.
  Future<int?> fetchTotalLaporanBulanIni({required String token}) async {
    try {
      final response =
          await _apiClient.post(ApiEndpoints.dashboardGetTotalLaporan, token: token);
      if (!isApiSuccess(response)) return null;
      return _asCount(response['data']);
    } on ApiNetworkException {
      return null;
    }
  }

  int? _asCount(dynamic data) {
    if (data is int) return data;
    if (data is String) return int.tryParse(data);
    if (data is Map) {
      for (final key in ['total', 'count', 'jumlah', 'total_laporan', 'totalLaporan']) {
        final value = data[key];
        if (value is int) return value;
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }
}
