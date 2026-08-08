import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../app_state.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';

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
          final body = jsonDecode(item.payloadJson);
          final response = await _apiClient.post(
            item.endpoint,
            body: body is Map<String, dynamic> ? body : <String, dynamic>{},
            token: token,
          );

          if (isApiSuccess(response)) {
            final data = response['data'] is Map<String, dynamic>
                ? response['data'] as Map<String, dynamic>
                : response;
            await SQLiteManager.instance.markSyncItemDone(item.id);
            await SQLiteManager.instance.upsertLocalReport(
              clientId: item.clientId,
              payloadJson: item.payloadJson,
              syncStatus: 'synced',
              serverId: data['id'] as int?,
              reportCode: data['report_code'] as String?,
            );
          } else {
            final message = extractApiMessage(response) ?? 'Server rejected the item';
            await SQLiteManager.instance.markSyncItemFailed(item.id, message);
            await SQLiteManager.instance.upsertLocalReport(
              clientId: item.clientId,
              payloadJson: item.payloadJson,
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
