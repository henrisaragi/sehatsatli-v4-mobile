import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

/// One row of `GET notifikasi`.
class AppNotification {
  AppNotification({
    required this.id,
    required this.jenis,
    required this.laporanId,
    required this.judul,
    required this.pesan,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        jenis: json['jenis'] as String? ?? '',
        laporanId: json['laporan_id'] as String?,
        judul: json['judul'] as String? ?? '',
        pesan: json['pesan'] as String? ?? '',
        isRead: json['read_at'] != null,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      );

  static const String jenisPenyakitAlert = 'penyakit_alert';

  final String id;

  /// `laporan_entitas` | `penyakit_alert`
  final String jenis;
  final String? laporanId;
  final String judul;
  final String pesan;
  bool isRead;
  final DateTime? createdAt;
}

class NotificationPage {
  NotificationPage({required this.items, required this.unreadCount, required this.hasMore});

  final List<AppNotification> items;
  final int unreadCount;
  final bool hasMore;
}

/// Server-side notifications (no offline cache: they only exist online).
class NotificationRepository {
  NotificationRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Null when the server refuses; throws [ApiNetworkException] when offline.
  Future<NotificationPage?> fetchPage({required String token, int page = 1, int perPage = 25}) async {
    final response = await _apiClient.request('GET', ApiEndpoints.notifikasi,
        token: token, query: {'page': page, 'per_page': perPage});
    if (!response.isSuccess) return null;
    final data = response.body['data'];
    final currentPage = (response.body['current_page'] as num?)?.toInt() ?? page;
    final lastPage = (response.body['last_page'] as num?)?.toInt() ?? currentPage;
    return NotificationPage(
      items: data is List
          ? data
              .whereType<Map>()
              .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [],
      unreadCount: (response.body['unread_count'] as num?)?.toInt() ?? 0,
      hasMore: currentPage < lastPage,
    );
  }

  Future<bool> markRead(String id, {required String token}) async =>
      (await _apiClient.request('POST', ApiEndpoints.notifikasiBaca(id), token: token)).isSuccess;

  Future<bool> markAllRead({required String token}) async =>
      (await _apiClient.request('POST', ApiEndpoints.notifikasiBacaSemua, token: token)).isSuccess;

  Future<void> registerDevice(String fcmToken, String platform, {required String token}) =>
      _apiClient.request('POST', ApiEndpoints.notifikasiPerangkat,
          token: token, body: {'token': fcmToken, 'platform': platform});

  /// Used during logout with the outgoing token — a 401 must not trigger the
  /// global session handler.
  Future<void> unregisterDevice(String fcmToken, {required String token}) =>
      _apiClient.request('DELETE', ApiEndpoints.notifikasiPerangkat,
          token: token,
          body: {'token': fcmToken},
          reportUnauthorized: false,
          timeout: const Duration(seconds: 10));
}
