import '../../backend/sqlite/sqlite_manager.dart';
import '../../flutter_flow/flutter_flow_util.dart';
import 'laporan_fields.dart';

/// One row in a report list (Beranda, Laporan, Sinkron) — built either from
/// a `local_reports` row or a `GET laporan` item.
class ReportListItem {
  ReportListItem({
    required this.species,
    required this.status,
    required this.syncStatus,
    required this.date,
    this.serverId,
    this.clientId,
    this.lastError,
  });

  factory ReportListItem.local(GetAllLocalReportsRow row) {
    final payload = _decode(row.payloadJson);
    final isLegacy = row.syncStatus == 'legacy';
    return ReportListItem(
      species: isLegacy ? 'Laporan versi lama' : jenisLabel(payload),
      status: isLegacy
          ? 'Versi lama'
          : (tahapLabels[payload['tahap']] ?? 'Draf'),
      syncStatus: row.syncStatus,
      date: _formatDate(row.updatedAt ?? row.createdAt),
      serverId: row.serverId,
      clientId: row.clientId,
      lastError: row.lastError,
    );
  }

  factory ReportListItem.server(Map<String, dynamic> laporan) => ReportListItem(
        species: jenisLabel(laporan),
        status: tahapLabels[laporan['tahap']] ?? '-',
        syncStatus: 'synced',
        date: _formatDate(laporan['created_at']?.toString() ?? ''),
        serverId: laporan['id']?.toString(),
      );

  final String species;

  /// Wizard stage label (Investigasi … Selesai).
  final String status;

  /// draft | pending | synced | failed | legacy
  final String syncStatus;
  final String date;
  final String? serverId;
  final String? clientId;
  final String? lastError;

  bool get isUnsent => syncStatus != 'synced';

  /// Only reports that never reached the server can be deleted (on-device);
  /// backend v4 has no delete endpoint.
  bool get isDeletable => clientId != null && serverId == null;

  /// Short server id for display, e.g. `#01a0497a`.
  String get shortId {
    final id = serverId;
    if (id == null) return 'Belum di server';
    return '#${id.length > 8 ? id.substring(0, 8) : id}';
  }

  /// Sync state while unsent, wizard stage once on the server.
  String get badge => isUnsent ? (syncStatusLabels[syncStatus] ?? syncStatus) : status;

  static const Map<String, String> syncStatusLabels = {
    'draft': 'Draf',
    'pending': 'Menunggu kirim',
    'failed': 'Gagal kirim',
    'legacy': 'Versi lama',
    'synced': 'Terkirim',
  };

  /// Local rows first (unsent ones on top), then server rows not already
  /// shown from local data.
  static List<ReportListItem> merge(
    List<GetAllLocalReportsRow> local,
    List<Map<String, dynamic>> server,
  ) {
    final serverIds = server.map((r) => r['id']?.toString()).toSet();
    final shown = local
        .where((r) => r.syncStatus != 'synced' || !serverIds.contains(r.serverId))
        .map(ReportListItem.local)
        .toList();
    final localItems = [
      ...shown.where((i) => i.isUnsent),
      ...shown.where((i) => !i.isUnsent),
    ];
    final localServerIds = localItems.map((i) => i.serverId).whereType<String>().toSet();
    return [
      ...localItems,
      ...server
          .where((r) => !localServerIds.contains(r['id']?.toString()))
          .map(ReportListItem.server),
    ];
  }

  static Map<String, dynamic> _decode(String? json) {
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  static String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    return parsed != null
        ? dateTimeFormat('dd MMMM yyyy', parsed.toLocal(), locale: 'id')
        : raw;
  }
}
