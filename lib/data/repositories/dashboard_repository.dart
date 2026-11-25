import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

/// `GET dashboard/ringkasan` — national laporan count plus a count per
/// entitas (UPT) the user belongs to, primary entitas first.
class DashboardSummary {
  DashboardSummary({required this.nasional, required this.entitas});

  final int nasional;

  /// `{id, nama_entitas, total}`
  final List<Map<String, dynamic>> entitas;
}

class DashboardRepository {
  DashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Null when offline or the server refuses — the dashboard just hides the card.
  Future<DashboardSummary?> fetchRingkasan({required String token}) async {
    try {
      final response = await _apiClient.request('GET', ApiEndpoints.dashboardRingkasan,
          token: token);
      if (!response.isSuccess) return null;
      final entitas = response.body['entitas'];
      return DashboardSummary(
        nasional: (response.body['nasional'] as num?)?.toInt() ?? 0,
        entitas: entitas is List
            ? entitas.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : [],
      );
    } on ApiNetworkException {
      return null;
    }
  }
}
