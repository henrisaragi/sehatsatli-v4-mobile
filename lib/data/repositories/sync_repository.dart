import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../app_state.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/laporan_fields.dart';

/// Queue method for a photo job: sign-upload → raw PUT to object storage →
/// register the object key. Not an HTTP verb.
const String syncMethodUploadPhoto = 'UPLOAD';

/// Drains `sync_queue` FIFO, one item at a time (CLAUDE.md §5.2). Items for
/// one report run in the order they were queued: create (`POST laporan`),
/// then stage updates and photos, whose endpoints carry a `{laporan}`
/// placeholder resolved from `local_reports.server_id` once the create has
/// synced.
class SyncRepository {
  SyncRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<void> runSyncQueue() async {
    if (kIsWeb) return; // sqflite has no web backend — nothing to drain.
    if (FFAppState().isSyncing) return;

    FFAppState().update(() => FFAppState().isSyncing = true);
    try {
      final token = FFAppState().accessToken;
      if (token == null) return;
      if (!await _apiClient.isReachable()) return;

      // Reports with a rejected item (until the user retries it) or whose
      // earlier item couldn't run yet — their later items must wait so
      // stages never reach the server out of order.
      final blocked = await SQLiteManager.instance.getClientIdsWithFailedSyncItems();

      for (final item in await SQLiteManager.instance.getPendingSyncQueue()) {
        if (blocked.contains(item.clientId)) continue;

        final local = await SQLiteManager.instance.getLocalReport(item.clientId);
        var path = item.endpoint;
        if (path.contains(ApiEndpoints.laporanPlaceholder)) {
          final serverId = local?.serverId;
          if (serverId == null) {
            blocked.add(item.clientId);
            continue;
          }
          path = path.replaceAll(ApiEndpoints.laporanPlaceholder, serverId);
        }

        final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
        final ApiResponse response;
        try {
          response = item.method == syncMethodUploadPhoto
              ? await _uploadPhoto(path, payload, token)
              : await _apiClient.request(item.method, path,
                  body: payload, token: token);
        } on ApiNetworkException catch (e) {
          await SQLiteManager.instance.incrementSyncItemRetry(item.id, e.toString());
          break; // connection dropped — stop until the next trigger.
        }

        if (response.isSuccess) {
          await SQLiteManager.instance.markSyncItemDone(item.id);
          await _applySuccess(item.clientId, item.endpoint, payload, response.body);
        } else if (response.statusCode == 401) {
          break; // session rejected — onUnauthorized already sent to login.
        } else if (response.isTransient) {
          await SQLiteManager.instance
              .incrementSyncItemRetry(item.id, response.message);
          break;
        } else {
          await SQLiteManager.instance.markSyncItemFailed(item.id, response.message);
          await _markReportFailed(item.clientId, response.message);
          blocked.add(item.clientId);
        }
      }
    } finally {
      FFAppState().update(() => FFAppState().isSyncing = false);
    }
  }

  Future<ApiResponse> _uploadPhoto(
    String fotoPath,
    Map<String, dynamic> payload,
    String token,
  ) async {
    final file = File(payload['local_path'] as String);
    if (!await file.exists()) {
      return ApiResponse(422, {'message': 'File foto tidak ditemukan di perangkat.'});
    }
    final contentType = payload['content_type'] as String? ?? 'image/jpeg';

    final sign = await _apiClient.request('POST', '$fotoPath/sign-upload',
        body: {'content_type': contentType}, token: token);
    if (!sign.isSuccess) return sign;

    final headers = (sign.body['headers'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        {'Content-Type': contentType};
    final status = await _apiClient.putBytes(
      sign.body['url'] as String,
      await file.readAsBytes(),
      headers: headers,
    );
    if (status < 200 || status >= 300) {
      // Object storage refused the upload; a fresh signed URL next time may
      // succeed, so treat it as transient rather than rejecting the photo.
      return ApiResponse(503, {'message': 'Unggah foto ke object storage gagal (HTTP $status).'});
    }

    return _apiClient.request('POST', fotoPath,
        body: {'object_key': sign.body['object_key']}, token: token);
  }

  /// Puts a report's rejected queue items back in line (user tapped
  /// "Kirim ulang"), then drains the queue.
  Future<void> retryFailed(String clientId) async {
    await SQLiteManager.instance.resetFailedSyncItems(clientId);
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    if (local != null) {
      await SQLiteManager.instance.upsertLocalReport(
        clientId: clientId,
        payloadJson: local.payloadJson ?? '{}',
        syncStatus: 'pending',
      );
    }
    await runSyncQueue();
  }

  Future<void> _applySuccess(
    String clientId,
    String endpoint,
    Map<String, dynamic> request,
    Map<String, dynamic> data,
  ) async {
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    if (local == null) return;
    final payload = jsonDecode(local.payloadJson ?? '{}') as Map<String, dynamic>;

    String? serverId;
    if (endpoint == ApiEndpoints.laporan) {
      serverId = data['id']?.toString();
    }
    if (endpoint == ApiEndpoints.laporanFoto) {
      payload['foto'] = [...?(payload['foto'] as List?), data];
      payload['foto_lokal'] = [...?(payload['foto_lokal'] as List?)]
        ..remove(request['local_path']);
    } else if (data['tahap'] is String) {
      // Never move the local stage backwards: stages queued after this one
      // already advanced it optimistically.
      final serverTahap = data['tahap'] as String;
      final localTahap = payload['tahap'] as String? ?? serverTahap;
      if (_tahapIndex(serverTahap) > _tahapIndex(localTahap)) {
        payload['tahap'] = serverTahap;
      }
      // The stage the server has confirmed, shown on the detail page.
      final confirmed = payload['tahap_server'] as String?;
      if (confirmed == null || _tahapIndex(serverTahap) > _tahapIndex(confirmed)) {
        payload['tahap_server'] = serverTahap;
      }
    }

    final open = await SQLiteManager.instance.countOpenSyncItems(clientId);
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode(payload),
      syncStatus: open == 0 ? 'synced' : local.syncStatus,
      serverId: serverId,
    );
  }

  Future<void> _markReportFailed(String clientId, String message) async {
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    if (local == null) return;
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: local.payloadJson ?? '{}',
      syncStatus: 'failed',
      lastError: message,
    );
  }

  static int _tahapIndex(String tahap) => tahapOrder.indexOf(tahap);
}
