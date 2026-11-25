import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../../app_state.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/laporan_fields.dart';
import 'sync_repository.dart';

enum ReportSubmitStatus { sent, queuedOffline, failed }

class ReportSubmitResult {
  ReportSubmitResult({required this.status, this.message});

  final ReportSubmitStatus status;
  final String? message;
}

class ReportListResult {
  ReportListResult({required this.reports, required this.hasMore, this.errorMessage});

  final List<Map<String, dynamic>> reports;
  final bool hasMore;
  final String? errorMessage;
}

/// Wizard stages after create, keyed by the `tahap` they fill.
const Map<String, String> stageEndpoints = {
  'investigasi': ApiEndpoints.laporanInvestigasi,
  'verifikasi_dokter': ApiEndpoints.laporanVerifikasiDokter,
  'hasil_lab': ApiEndpoints.laporanHasilLab,
};

/// Offline-first laporan writes. Every write lands in `local_reports` (a
/// flat snapshot shaped like `GET laporan/{id}`) and `sync_queue` first; the
/// queue is then drained by [SyncRepository], immediately when online.
class ReportRepository {
  ReportRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _syncRepository = SyncRepository(apiClient: apiClient);

  final ApiClient _apiClient;
  final SyncRepository _syncRepository;

  /// Device-generated id, sent as `client_uuid` so a retried create returns
  /// the same server laporan instead of a duplicate.
  String newClientId() => const Uuid().v4();

  /// Saves an unfinished new-report form locally without queueing anything.
  Future<void> saveDraft({
    required String clientId,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) return;
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode(payload),
      syncStatus: 'draft',
    );
  }

  /// Queues a new laporan (`POST laporan`), its investigation stage and its
  /// photos in one go, then tries to send them.
  Future<ReportSubmitResult> createWithInvestigasi({
    required String clientId,
    required Map<String, dynamic> createPayload,
    Map<String, dynamic> display = const {},
    required Map<String, dynamic> investigasi,
    List<String> photoPaths = const [],
  }) async {
    final create = {...createPayload, 'client_uuid': clientId};
    await _writeLocal(clientId, {
      ...display,
      ...create,
      ...investigasi,
      'tahap': nextTahap('investigasi'),
      'foto_lokal': photoPaths,
    });
    await _enqueue(clientId, ApiEndpoints.laporan, 'POST', create);
    await _enqueue(clientId, ApiEndpoints.laporanInvestigasi, 'PUT', investigasi);
    await _enqueuePhotos(clientId, photoPaths);
    return _drain(clientId);
  }

  /// Queues the form of [tahap] (`investigasi`, `verifikasi_dokter` or
  /// `hasil_lab`) for an existing local report, then tries to send it.
  Future<ReportSubmitResult> submitStage({
    required String clientId,
    required String tahap,
    required Map<String, dynamic> payload,
    Map<String, dynamic> display = const {},
    List<String> photoPaths = const [],
  }) async {
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    final current = jsonDecode(local?.payloadJson ?? '{}') as Map<String, dynamic>;
    await _writeLocal(clientId, {
      ...current,
      ...display,
      ...payload,
      'tahap': nextTahap(tahap),
      'foto_lokal': [...?(current['foto_lokal'] as List?), ...photoPaths],
    });
    await _enqueue(clientId, stageEndpoints[tahap]!, 'PUT', payload);
    await _enqueuePhotos(clientId, photoPaths);
    return _drain(clientId);
  }

  /// Puts the report's rejected queue items back in line and resends.
  Future<ReportSubmitResult> retry(String clientId) async {
    await _syncRepository.retryFailed(clientId);
    return _statusOf(clientId);
  }

  /// Removes a report that only exists on this device. Backend v4 has no
  /// delete endpoint, so reports already on the server can't be removed here.
  Future<void> deleteLocal(String clientId) async {
    if (kIsWeb) return;
    await SQLiteManager.instance.deleteLocalReport(clientId);
  }

  /// Makes sure a server laporan opened on this device has a local row, so
  /// its next stage can be queued offline. Returns the local client id.
  Future<String> ensureLocalRow(Map<String, dynamic> remote) async {
    final serverId = remote['id'].toString();
    for (final row in await SQLiteManager.instance.getAllLocalReports()) {
      if (row.serverId == serverId) {
        final local = jsonDecode(row.payloadJson ?? '{}') as Map<String, dynamic>;
        // Stages still waiting in the queue are newer than the server copy.
        final merged = row.syncStatus == 'synced'
            ? {...local, ...remote, 'foto_lokal': local['foto_lokal']}
            : {...remote, ...local};
        await SQLiteManager.instance.upsertLocalReport(
          clientId: row.clientId,
          payloadJson: jsonEncode(merged),
          syncStatus: row.syncStatus,
        );
        return row.clientId;
      }
    }
    final clientId = remote['client_uuid']?.toString() ?? newClientId();
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode(remote),
      syncStatus: 'synced',
      serverId: serverId,
    );
    return clientId;
  }

  /// `GET laporan` (all) or `GET laporan/saya` (mine), 25 per page. Network
  /// failures propagate as [ApiNetworkException].
  Future<ReportListResult> fetchReports({
    required int page,
    required String token,
    bool mine = false,
  }) async {
    final response = await _apiClient.request(
      'GET',
      mine ? ApiEndpoints.laporanSaya : ApiEndpoints.laporan,
      query: {'page': page, 'per_page': 25},
      token: token,
    );
    if (!response.isSuccess) {
      return ReportListResult(reports: [], hasMore: false, errorMessage: response.message);
    }
    final items = response.body['data'];
    final currentPage = response.body['current_page'] as int? ?? page;
    final lastPage = response.body['last_page'] as int? ?? currentPage;
    return ReportListResult(
      reports: items is List
          ? items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [],
      hasMore: currentPage < lastPage,
    );
  }

  /// `GET laporan/{id}` — full detail incl. `barang_bukti` and `foto` (with
  /// signed download URLs). Null if the server doesn't return it.
  Future<Map<String, dynamic>?> fetchOne({
    required String id,
    required String token,
  }) async {
    final response = await _apiClient.request(
      'GET',
      ApiEndpoints.laporanDetail(id),
      token: token,
    );
    return response.isSuccess ? response.body : null;
  }

  Future<void> _writeLocal(String clientId, Map<String, dynamic> payload) async {
    if (kIsWeb) return;
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode(payload),
      syncStatus: 'pending',
    );
  }

  Future<void> _enqueue(
    String clientId,
    String endpoint,
    String method,
    Map<String, dynamic> payload,
  ) async {
    if (kIsWeb) return;
    await SQLiteManager.instance.enqueueSyncItem(
      clientId: clientId,
      endpoint: endpoint,
      method: method,
      payloadJson: jsonEncode(payload),
    );
  }

  Future<void> _enqueuePhotos(String clientId, List<String> paths) async {
    for (final path in paths) {
      await _enqueue(clientId, ApiEndpoints.laporanFoto, syncMethodUploadPhoto, {
        'local_path': path,
        'content_type': 'image/jpeg',
      });
    }
  }

  Future<ReportSubmitResult> _drain(String clientId) async {
    if (FFAppState().accessToken != null) {
      await _syncRepository.runSyncQueue();
    }
    return _statusOf(clientId);
  }

  Future<ReportSubmitResult> _statusOf(String clientId) async {
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    switch (local?.syncStatus) {
      case 'synced':
        return ReportSubmitResult(status: ReportSubmitStatus.sent);
      case 'failed':
        return ReportSubmitResult(
          status: ReportSubmitStatus.failed,
          message: local?.lastError,
        );
      default:
        return ReportSubmitResult(status: ReportSubmitStatus.queuedOffline);
    }
  }
}
