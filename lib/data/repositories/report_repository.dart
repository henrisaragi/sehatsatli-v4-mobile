import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';

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
      await SQLiteManager.instance.upsertLocalReport(
        clientId: clientId,
        payloadJson: payloadJson,
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
          await SQLiteManager.instance.upsertLocalReport(
            clientId: clientId,
            payloadJson: payloadJson,
            syncStatus: 'failed',
          );
        }
        return ReportSubmitResult(status: ReportSubmitStatus.failed, message: message);
      }

      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      final serverId = data['id'] as int?;
      final reportCode = data['report_code'] as String?;

      if (queueId != null) {
        await SQLiteManager.instance.markSyncItemDone(queueId);
      }
      if (!kIsWeb) {
        await SQLiteManager.instance.upsertLocalReport(
          clientId: clientId,
          payloadJson: payloadJson,
          syncStatus: 'synced',
          serverId: serverId,
          reportCode: reportCode,
        );
      }
      return ReportSubmitResult(status: ReportSubmitStatus.sentImmediately);
    } on ApiNetworkException {
      // Stays queued in sync_queue with sync_status 'pending' — safe to
      // retry later since the server dedupes on client_id.
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
      ApiEndpoints.getGeneralReportMobile,
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

  /// Rebuilds a full `saveGeneralReportMobile`-shaped payload from a
  /// [fetchOne] response, replacing exactly one of the `verification`/`lab`/
  /// `investigation` sections with freshly-edited data and carrying the rest
  /// over unchanged — used by the Step-5 forms, which only edit one section
  /// at a time but must resubmit the whole report (the server has no
  /// per-section save endpoint). The exact key `getOne` uses for the
  /// location relation isn't confirmed (API_ENDPOINTS.md's prose says
  /// "location" singular but the save payload key is "locations" plural), so
  /// both are tried defensively.
  Map<String, dynamic> mergeSection(
    Map<String, dynamic> existingReport,
    String sectionKey,
    Map<String, dynamic> sectionData,
  ) {
    Map<String, dynamic>? asMap(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : null;

    final sections = {
      'verification': asMap(existingReport['verification']),
      'lab': asMap(existingReport['lab']),
      'investigation': asMap(existingReport['investigation']),
    };
    sections[sectionKey] = sectionData;

    return {
      'report_date': existingReport['report_date'],
      'description': existingReport['description'],
      'reporter': asMap(existingReport['reporter']) ?? <String, dynamic>{},
      'locations': asMap(existingReport['locations']) ??
          asMap(existingReport['location']) ??
          <String, dynamic>{},
      'species': asMap(existingReport['species']) ?? <String, dynamic>{},
      'diagnoses': asMap(existingReport['diagnoses']) ?? <String, dynamic>{},
      'verification': sections['verification'],
      'lab': sections['lab'],
      'investigation': sections['investigation'],
    };
  }
}
