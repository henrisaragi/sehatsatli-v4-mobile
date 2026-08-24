import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../app_state.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';
import 'local_report_merge.dart';

/// Implements the sync algorithm documented in CLAUDE.md/design_system_mobile.md
/// §7.4 — the outbox-draining half of offline-first. Drains `sync_queue` FIFO,
/// one item at a time (never in parallel, so a create→update pair for the
/// same client_id can't race each other on the server).
class SyncRepository {
  SyncRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> runSyncQueue() async {
    if (kIsWeb) return; // sqflite has no web backend — nothing to drain.
    if (FFAppState().isSyncing) return; // guard against concurrent runs.

    FFAppState().update(() => FFAppState().isSyncing = true);
    try {
      final token = FFAppState().accessToken;
      if (token == null) return;
      if (!await _isReachable()) return;

      final pending = await SQLiteManager.instance.getPendingSyncQueue();
      for (final item in pending) {
        try {
          final decoded = jsonDecode(item.payloadJson);
          final outgoingPayload =
              decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

          Map<String, dynamic> body;
          if (outgoingPayload['_resolveIdFromClientId'] == true) {
            // Tab 2-4 section save queued before its report's own create had
            // synced yet. Re-check now — a create enqueued earlier in this
            // same FIFO pass may have already resolved it.
            final local = await SQLiteManager.instance.getLocalReport(item.clientId);
            if (local?.serverId == null) {
              // Still unresolved — leave this item pending untouched (no
              // status change, no retry bump) and move on to the next
              // unrelated queue item; it'll be retried on a later pass.
              continue;
            }
            body = {...outgoingPayload}
              ..remove('_resolveIdFromClientId')
              ..remove('_sectionKey')
              ..['id'] = local!.serverId;
          } else {
            body = {...outgoingPayload}..remove('_sectionKey');
          }

          final response = await _apiClient.post(
            item.endpoint,
            body: body,
            token: token,
          );

          if (isApiSuccess(response)) {
            final data = response['data'] is Map<String, dynamic>
                ? response['data'] as Map<String, dynamic>
                : response;

            // Same guard as `ReportRepository.submit()` against the
            // `success: true, data: null` anomaly documented on
            // `ApiEndpoints.generalReportsSave` — this drained-queue path
            // hits the same endpoint for reports that were queued offline,
            // so it needs the same protection against silently marking a
            // never-actually-created report 'synced'. `body['id']` covers
            // both an update/section-save that already carried a known id
            // and a fresh create that legitimately omits it.
            final existingServerId = body['id'] as int?;
            if (data['id'] == null && existingServerId == null) {
              const message =
                  'Server tidak mengonfirmasi ID laporan — kemungkinan tidak tersimpan.';
              await SQLiteManager.instance.markSyncItemFailed(item.id, message);
              await applyServerResultToLocalReport(
                clientId: item.clientId,
                outgoingPayload: outgoingPayload,
                responseData: const {},
                syncStatus: 'failed',
              );
              continue;
            }

            await SQLiteManager.instance.markSyncItemDone(item.id);
            await applyServerResultToLocalReport(
              clientId: item.clientId,
              outgoingPayload: outgoingPayload,
              responseData: data,
              syncStatus: 'synced',
            );
          } else {
            final message = extractApiMessage(response) ?? 'Server rejected the item';
            await SQLiteManager.instance.markSyncItemFailed(item.id, message);
            await applyServerResultToLocalReport(
              clientId: item.clientId,
              outgoingPayload: outgoingPayload,
              responseData: const {},
              syncStatus: 'failed',
            );
            // Not a connectivity problem — keep draining the rest of the queue.
          }
        } on ApiNetworkException catch (e) {
          await SQLiteManager.instance.incrementSyncItemRetry(item.id, e.toString());
          // Assume the connection dropped again — stop burning through the
          // rest of the queue until the next trigger.
          break;
        }
      }
    } finally {
      FFAppState().update(() => FFAppState().isSyncing = false);
    }
  }

  Future<bool> _isReachable() async {
    try {
      await _apiClient.get(ApiEndpoints.ping, timeout: const Duration(seconds: 5));
      return true;
    } on ApiNetworkException {
      return false;
    }
  }
}
