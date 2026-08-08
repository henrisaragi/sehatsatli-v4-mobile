import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';
import 'local_report_merge.dart';

enum ReportSubmitStatus { sentImmediately, queuedOffline, failed }

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

class ReportRepository {
  ReportRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Generated once per new report and reused for every subsequent
  /// draft-save/submit/retry of that same report — the server uses this as
  /// the idempotency key for create-vs-update (API_ENDPOINTS.md §3).
  String newClientId() => const Uuid().v4();

  Future<void> saveDraft({
    required String clientId,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) return;
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode({...payload, 'client_id': clientId}),
      syncStatus: 'draft',
    );
  }

  /// Always persists locally first and queues a sync_queue entry (the
  /// offline outbox), then makes one immediate send attempt if [token] is
  /// available. A full background retry worker that watches connectivity is
  /// a separate piece of work (Fase 3d) — this just makes the first attempt
  /// and leaves the row queued on failure.
  Future<ReportSubmitResult> submit({
    required String clientId,
    required Map<String, dynamic> payload,
    String? token,
    String endpoint = ApiEndpoints.saveGeneralReportMobile,
  }) async {
    final payloadWithId = {...payload, 'client_id': clientId};
    final payloadJson = jsonEncode(payloadWithId);

    int? queueId;
    if (!kIsWeb) {
      await applyServerResultToLocalReport(
        clientId: clientId,
        outgoingPayload: payloadWithId,
        responseData: const {},
        syncStatus: 'pending',
      );
      queueId = await SQLiteManager.instance.enqueueSyncItem(
        clientId: clientId,
        endpoint: endpoint,
        payloadJson: payloadJson,
      );
    }

    if (token == null) {
      return ReportSubmitResult(status: ReportSubmitStatus.queuedOffline);
    }

    try {
      final response = await _apiClient.post(
        endpoint,
        body: payloadWithId,
        token: token,
      );

      if (!isApiSuccess(response)) {
        final message = extractApiMessage(response);
        if (queueId != null) {
          await SQLiteManager.instance
              .markSyncItemFailed(queueId, message ?? 'Server rejected the report');
        }
        if (!kIsWeb) {
          await applyServerResultToLocalReport(
            clientId: clientId,
            outgoingPayload: payloadWithId,
            responseData: const {},
            syncStatus: 'failed',
          );
        }
        return ReportSubmitResult(status: ReportSubmitStatus.failed, message: message);
      }

      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;

      if (queueId != null) {
        await SQLiteManager.instance.markSyncItemDone(queueId);
      }
      if (!kIsWeb) {
        await applyServerResultToLocalReport(
          clientId: clientId,
          outgoingPayload: payloadWithId,
          responseData: data,
          syncStatus: 'synced',
        );
      }
      return ReportSubmitResult(status: ReportSubmitStatus.sentImmediately);
    } on ApiNetworkException {
      // Stays queued in sync_queue with sync_status 'pending' — safe to
      // retry later since the server dedupes on client_id.
      return ReportSubmitResult(status: ReportSubmitStatus.queuedOffline);
    }
  }

  /// Full Report Tabs 2-4 (Verifikasi/Lab/Investigasi Lanjutan) — unlike
  /// [submit], each of these endpoints (saveVerify/saveLab/saveInvestigation)
  /// takes only that tab's flat fields plus a hidden `id` = the report's
  /// server id, and must NOT replace the whole `local_reports.payload_json`
  /// snapshot the way [submit] does (that would wipe out the other tabs'
  /// cached data — see [applyServerResultToLocalReport]).
  ///
  /// Because these endpoints operate on an already-existing report row, they
  /// need a numeric server id. Under offline-first that id may not exist yet
  /// if the report's own create (Tab 1 / Quick Report) hasn't synced — in
  /// that case this queues the section with a `_resolveIdFromClientId`
  /// marker instead of attempting a POST that's guaranteed to fail; see
  /// `SyncRepository.runSyncQueue`, which resolves the real id from
  /// `local_reports.server_id` right before sending once it's known.
  ///
  /// Requires a `local_reports` row to already exist for [clientId] (i.e.
  /// Tab 1 has been saved locally at least once) — callers should disable
  /// Tabs 2-4 until that's true rather than relying on the failure message
  /// below.
  Future<ReportSubmitResult> submitSection({
    required String clientId,
    required String sectionKey,
    required Map<String, dynamic> sectionPayload,
    required String endpoint,
    String? token,
  }) async {
    final existing = await SQLiteManager.instance.getLocalReport(clientId);
    if (existing == null) {
      return ReportSubmitResult(
        status: ReportSubmitStatus.failed,
        message: 'Laporan awal (Investigasi) belum pernah disimpan.',
      );
    }

    final serverId = existing.serverId;
    final outgoingPayload = <String, dynamic>{
      ...sectionPayload,
      'client_id': clientId,
      '_sectionKey': sectionKey,
      if (serverId != null) 'id': serverId else '_resolveIdFromClientId': true,
    };
    final payloadJson = jsonEncode(outgoingPayload);

    int? queueId;
    if (!kIsWeb) {
      queueId = await SQLiteManager.instance.enqueueSyncItem(
        clientId: clientId,
        endpoint: endpoint,
        payloadJson: payloadJson,
      );
      await applyServerResultToLocalReport(
        clientId: clientId,
        outgoingPayload: outgoingPayload,
        responseData: const {},
        syncStatus: 'pending',
      );
    }

    if (serverId == null) {
      // Guaranteed to fail server-side without a real report id — leave it
      // queued for the sync engine to resolve once Tab 1 has synced.
      return ReportSubmitResult(status: ReportSubmitStatus.queuedOffline);
    }

    if (token == null) {
      return ReportSubmitResult(status: ReportSubmitStatus.queuedOffline);
    }

    try {
      final response = await _apiClient.post(
        endpoint,
        body: {...outgoingPayload}..remove('_sectionKey'),
        token: token,
      );

      if (!isApiSuccess(response)) {
        final message = extractApiMessage(response);
        if (queueId != null) {
          await SQLiteManager.instance
              .markSyncItemFailed(queueId, message ?? 'Server rejected the report');
        }
        if (!kIsWeb) {
          await applyServerResultToLocalReport(
            clientId: clientId,
            outgoingPayload: outgoingPayload,
            responseData: const {},
            syncStatus: 'failed',
          );
        }
        return ReportSubmitResult(status: ReportSubmitStatus.failed, message: message);
      }

      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;

      if (queueId != null) {
        await SQLiteManager.instance.markSyncItemDone(queueId);
      }
      if (!kIsWeb) {
        await applyServerResultToLocalReport(
          clientId: clientId,
          outgoingPayload: outgoingPayload,
          responseData: data,
          syncStatus: 'synced',
        );
      }
      return ReportSubmitResult(status: ReportSubmitStatus.sentImmediately);
    } on ApiNetworkException {
      return ReportSubmitResult(status: ReportSubmitStatus.queuedOffline);
    }
  }

  Future<bool> delete(String clientId, {required String token}) async {
    final response = await _apiClient.post(
      ApiEndpoints.deleteGeneralReportMobile,
      body: {'client_id': clientId},
      token: token,
    );
    return isApiSuccess(response);
  }

  /// [training] maps to the `{ id: 1|0 }` body flag API_ENDPOINTS.md §3
  /// documents for filtering training vs. production data — an unfortunate
  /// name collision with the report's own server `id`, but that's the
  /// server's literal contract. Lets [ApiNetworkException] propagate to the
  /// caller (no connection); a server-side rejection instead comes back as
  /// an empty list + [ReportListResult.errorMessage].
  Future<ReportListResult> fetchReports({
    required bool training,
    required int page,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.generalReportsGetAll,
      body: {'id': training ? 1 : 0, 'page': page},
      token: token,
    );

    if (!isApiSuccess(response)) {
      return ReportListResult(
        reports: [],
        hasMore: false,
        errorMessage: extractApiMessage(response) ?? 'Gagal memuat laporan',
      );
    }

    final data = response['data'];
    List<dynamic> items;
    bool hasMore;
    // Response is expected to be a Laravel paginator ({data, current_page,
    // last_page, ...}) but the exact shape isn't confirmed against a live
    // response yet — fall back to treating `data` as a bare list.
    if (data is Map<String, dynamic> && data['data'] is List) {
      items = data['data'] as List;
      final currentPage = data['current_page'] as int? ?? page;
      final lastPage = data['last_page'] as int? ?? currentPage;
      hasMore = currentPage < lastPage;
    } else if (data is List) {
      items = data;
      hasMore = items.length >= 10; // best-effort: doc says 10/page
    } else {
      items = const [];
      hasMore = false;
    }

    return ReportListResult(
      reports:
          items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      hasMore: hasMore,
    );
  }

  /// Returns the full nested report (reporter/locations/species/diagnoses +
  /// verification/lab/investigation if present), or null if not found /
  /// rejected by the server.
  Future<Map<String, dynamic>?> fetchOne({
    required dynamic id,
    required String token,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.getOne,
      body: {'id': id},
      token: token,
    );
    if (!isApiSuccess(response)) return null;
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

}
