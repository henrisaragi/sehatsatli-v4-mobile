import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/laporan_fields.dart';
import 'sync_repository.dart';

enum ReportSubmitStatus { sent, queuedOffline, failed }

class ReportSubmitResult {
  ReportSubmitResult({required this.status, this.message});

  final ReportSubmitStatus status;

  /// [ReportSubmitStatus.failed]: what the server rejected.
  /// [ReportSubmitStatus.queuedOffline]: why it couldn't be sent yet.
  final String? message;

  /// One line for the user: outcome plus what to do next.
  String get userMessage => switch (status) {
        ReportSubmitStatus.sent => 'Terkirim ke server.',
        ReportSubmitStatus.queuedOffline => message ??
            'Tersimpan di perangkat — dikirim otomatis saat online.',
        ReportSubmitStatus.failed => '${message ?? 'Server menolak laporan.'}\n\n'
            'Periksa data di atas, lalu tekan "Kirim ulang".',
      };
}

/// A stage the server rejected, with the data that was sent, so the user
/// can correct it.
class RejectedStage {
  RejectedStage({required this.tahap, required this.payload, required this.error});

  final String tahap;
  final Map<String, dynamic> payload;
  final String error;
}

/// Which server report list to fetch.
enum ReportListScope { mine, entitas }

class ReportListResult {
  ReportListResult({
    required this.reports,
    required this.hasMore,
    this.total = 0,
    this.errorMessage,
  });

  final List<Map<String, dynamic>> reports;
  final bool hasMore;

  /// Total matching reports across all pages.
  final int total;
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
    await _enqueue(
        clientId, ApiEndpoints.laporanInvestigasi, 'PUT', investigasi);
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
    final current =
        jsonDecode(local?.payloadJson ?? '{}') as Map<String, dynamic>;
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
    final run = await _syncRepository.retryFailed(clientId);
    return _statusOf(clientId, run);
  }

  /// The stage form the server rejected for [clientId], or null when nothing
  /// is rejected or what was rejected isn't a stage (the create or a photo).
  Future<RejectedStage?> rejectedStage(String clientId) async {
    if (kIsWeb) return null;
    final item = await SQLiteManager.instance.getFailedSyncItem(clientId);
    if (item == null) return null;
    final tahap = stageEndpoints.entries
        .where((e) => e.value == item.endpoint)
        .map((e) => e.key)
        .firstOrNull;
    if (tahap == null) return null;
    return RejectedStage(
      tahap: tahap,
      payload: jsonDecode(item.payloadJson) as Map<String, dynamic>,
      error: item.lastError ?? 'Ditolak server.',
    );
  }

  /// Sends corrected data for the rejected stage [tahap]: the rejected job
  /// gets the new request in its own queue slot (so stages still reach the
  /// server in order), the local snapshot shows the corrected values, and
  /// the queue is drained.
  Future<ReportSubmitResult> resubmitRejectedStage({
    required String clientId,
    required String tahap,
    required Map<String, dynamic> payload,
    Map<String, dynamic> display = const {},
    List<String> photoPaths = const [],
  }) async {
    final item = await SQLiteManager.instance.getFailedSyncItem(clientId);
    if (item == null || item.endpoint != stageEndpoints[tahap]) {
      // Nothing rejected any more (e.g. retried meanwhile) — just resend.
      return retry(clientId);
    }
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    final current = jsonDecode(local?.payloadJson ?? '{}') as Map<String, dynamic>;
    await SQLiteManager.instance.replaceSyncItemPayload(item.id, jsonEncode(payload));
    await _writeLocal(clientId, {
      ...current,
      ...display,
      ...payload,
      'foto_lokal': [...?(current['foto_lokal'] as List?), ...photoPaths],
    });
    await _enqueuePhotos(clientId, photoPaths);
    return _drain(clientId);
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
        final local =
            jsonDecode(row.payloadJson ?? '{}') as Map<String, dynamic>;
        // Stages still waiting in the queue are newer than the server copy.
        final merged = row.syncStatus == 'synced'
            ? {...local, ...remote, 'foto_lokal': local['foto_lokal']}
            : {...remote, ...local};
        merged['tahap_server'] = remote['tahap'];
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
      payloadJson: jsonEncode({...remote, 'tahap_server': remote['tahap']}),
      syncStatus: 'synced',
      serverId: serverId,
    );
    return clientId;
  }

  /// `GET laporan/saya` (mine) or `GET laporan/entitas` (everyone in the
  /// user's entitas), 25 per page. Network
  /// failures propagate as [ApiNetworkException].
  Future<ReportListResult> fetchReports({
    required int page,
    required String token,
    required ReportListScope scope,
    String? tahap,
    int perPage = 25,
  }) async {
    final response = await _apiClient.request(
      'GET',
      switch (scope) {
        ReportListScope.mine => ApiEndpoints.laporanSaya,
        ReportListScope.entitas => ApiEndpoints.laporanEntitas,
      },
      query: {
        'page': page,
        'per_page': perPage,
        if (tahap != null) 'tahap': tahap
      },
      token: token,
    );
    if (!response.isSuccess) {
      return ReportListResult(
          reports: [], hasMore: false, errorMessage: response.message);
    }
    final items = response.body['data'];
    final currentPage = response.body['current_page'] as int? ?? page;
    final lastPage = response.body['last_page'] as int? ?? currentPage;
    return ReportListResult(
      reports: items is List
          ? items
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : [],
      hasMore: currentPage < lastPage,
      total: (response.body['total'] as num?)?.toInt() ?? 0,
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

  Future<void> _writeLocal(
      String clientId, Map<String, dynamic> payload) async {
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
      await _enqueue(
          clientId, ApiEndpoints.laporanFoto, syncMethodUploadPhoto, {
        'local_path': path,
        'content_type': 'image/jpeg',
      });
    }
  }

  Future<ReportSubmitResult> _drain(String clientId) async {
    return _statusOf(clientId, await _syncRepository.runSyncQueue());
  }

  Future<ReportSubmitResult> _statusOf(String clientId, SyncRunResult run) async {
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
        return ReportSubmitResult(
          status: ReportSubmitStatus.queuedOffline,
          message: run.stopMessage,
        );
    }
  }
}
