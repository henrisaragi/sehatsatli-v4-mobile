import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../app_state.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error_text.dart';
import '../models/laporan_fields.dart';
import 'report_repository.dart' show stageEndpoints;

/// Queue method for a photo job: sign-upload → raw PUT to object storage →
/// register the object key. Not an HTTP verb.
const String syncMethodUploadPhoto = 'UPLOAD';

/// Why a sync run stopped before working through the whole queue.
enum SyncStop {
  /// Ran through every job it could.
  none,

  /// Another run was already in progress.
  busy,

  /// No session token.
  notLoggedIn,

  /// The health check failed — no internet, or the server is unreachable.
  unreachable,

  /// The connection dropped mid-run.
  connectionLost,

  /// The server answered 5xx/408; the job stays queued.
  serverError,

  /// The server rejected the session (401).
  sessionExpired,
}

/// Outcome of one [SyncRepository.runSyncQueue] call, for the screens that
/// trigger it to tell the user what happened and what to do.
class SyncRunResult {
  SyncRunResult({
    this.stop = SyncStop.none,
    this.serverMessage,
    this.sentClientIds = const {},
    this.rejected = const {},
  });

  final SyncStop stop;

  /// The server's message when [stop] is [SyncStop.serverError].
  final String? serverMessage;

  /// Reports fully sent during this run.
  final Set<String> sentClientIds;

  /// Reports the server rejected (4xx), with the reason.
  final Map<String, String> rejected;

  /// Why queued reports are still waiting, or null when nothing stopped the
  /// run. Always says the data is safe and what to do next.
  String? get stopMessage => switch (stop) {
        SyncStop.none => null,
        SyncStop.busy =>
          'Pengiriman lain sedang berjalan. Tunggu sebentar, lalu cek lagi.',
        SyncStop.notLoggedIn ||
        SyncStop.sessionExpired =>
          'Sesi Anda berakhir. Silakan masuk kembali — laporan tetap tersimpan '
              'di perangkat dan dikirim setelah masuk.',
        SyncStop.unreachable =>
          '$networkErrorText Laporan tetap tersimpan di perangkat dan dikirim '
              'otomatis saat koneksi kembali.',
        SyncStop.connectionLost =>
          'Koneksi terputus saat mengirim. Laporan yang belum terkirim tetap '
              'tersimpan — coba lagi saat sinyal stabil.',
        SyncStop.serverError =>
          '${serverMessage ?? serverErrorText(500)} Laporan tetap tersimpan '
              'di perangkat.',
      };

  /// One summary for a manual "Sync" tap.
  String summary({required int draftCount}) {
    final parts = <String>[
      if (sentClientIds.isNotEmpty) '${sentClientIds.length} laporan terkirim.',
      if (rejected.isNotEmpty)
        '${rejected.length} laporan ditolak server. Buka laporan bertanda '
            '"Gagal kirim" untuk melihat data yang perlu diperbaiki.',
      if (stopMessage != null) stopMessage!,
    ];
    if (parts.isEmpty) {
      parts.add(draftCount > 0
          ? 'Tidak ada laporan di antrean kirim.'
          : 'Semua laporan sudah terkirim.');
    }
    if (draftCount > 0) {
      parts.add('$draftCount laporan masih Draf dan tidak ikut terkirim — '
          'buka, lengkapi, lalu tekan "Kirim Laporan".');
    }
    return parts.join('\n\n');
  }

  /// Whether the user should see this as a problem rather than a success.
  bool get hasProblem => stop != SyncStop.none || rejected.isNotEmpty;
}

/// Drains `sync_queue` FIFO, one item at a time (CLAUDE.md §5.2). Items for
/// one report run in the order they were queued: create (`POST laporan`),
/// then stage updates and photos, whose endpoints carry a `{laporan}`
/// placeholder resolved from `local_reports.server_id` once the create has
/// synced.
class SyncRepository {
  SyncRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<SyncRunResult> runSyncQueue() async {
    if (kIsWeb) return SyncRunResult(); // sqflite has no web backend.
    if (FFAppState().isSyncing) return SyncRunResult(stop: SyncStop.busy);

    FFAppState().update(() => FFAppState().isSyncing = true);
    final sent = <String>{};
    final rejected = <String, String>{};
    try {
      final token = FFAppState().accessToken;
      if (token == null) return SyncRunResult(stop: SyncStop.notLoggedIn);
      if (!await _apiClient.isReachable()) {
        await _notePendingReason(SyncRunResult(stop: SyncStop.unreachable));
        return SyncRunResult(stop: SyncStop.unreachable);
      }

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
          return _stopped(SyncRunResult(
              stop: SyncStop.connectionLost, sentClientIds: sent, rejected: rejected));
        } on ApiRateLimitException {
          await SQLiteManager.instance.incrementSyncItemRetry(item.id, rateLimitText);
          return _stopped(SyncRunResult(
              stop: SyncStop.serverError,
              serverMessage: rateLimitText,
              sentClientIds: sent,
              rejected: rejected));
        }

        if (response.isSuccess) {
          await SQLiteManager.instance.markSyncItemDone(item.id);
          if (await _applySuccess(item.clientId, item.endpoint, payload, response.body)) {
            sent.add(item.clientId);
          }
        } else if (response.statusCode == 401) {
          // Session rejected — onUnauthorized already sent to login.
          return SyncRunResult(
              stop: SyncStop.sessionExpired, sentClientIds: sent, rejected: rejected);
        } else if (response.isTransient) {
          await SQLiteManager.instance
              .incrementSyncItemRetry(item.id, response.message);
          return _stopped(SyncRunResult(
              stop: SyncStop.serverError,
              serverMessage: response.message,
              sentClientIds: sent,
              rejected: rejected));
        } else {
          final reason = _rejectionText(item, response);
          await SQLiteManager.instance.markSyncItemFailed(item.id, reason);
          await _markReportFailed(item.clientId, reason);
          rejected[item.clientId] = reason;
          blocked.add(item.clientId);
        }
      }
      return SyncRunResult(sentClientIds: sent, rejected: rejected);
    } finally {
      FFAppState().update(() => FFAppState().isSyncing = false);
    }
  }

  /// Records on every still-pending report why this run couldn't send it,
  /// so Sync Manager can show it next to the report.
  Future<SyncRunResult> _stopped(SyncRunResult result) async {
    await _notePendingReason(result);
    return result;
  }

  Future<void> _notePendingReason(SyncRunResult result) async {
    final reason = result.stopMessage;
    if (reason == null) return;
    for (final row in await SQLiteManager.instance.getAllLocalReports()) {
      if (row.syncStatus != 'pending') continue;
      await SQLiteManager.instance.upsertLocalReport(
        clientId: row.clientId,
        payloadJson: row.payloadJson ?? '{}',
        syncStatus: 'pending',
        lastError: reason,
      );
    }
  }

  /// "Which part was rejected" + the server's per-field reasons.
  static String _rejectionText(GetPendingSyncQueueRow item, ApiResponse response) {
    final part = item.method == syncMethodUploadPhoto
        ? 'Foto'
        : item.endpoint == ApiEndpoints.laporan
            ? 'Data jenis satwa'
            : switch (stageEndpoints.entries
                .where((e) => e.value == item.endpoint)
                .map((e) => e.key)
                .firstOrNull) {
                final String tahap => 'Data ${tahapLabels[tahap] ?? tahap}',
                null => 'Data laporan',
              };
    return '$part ditolak server:\n${response.message}';
  }

  Future<ApiResponse> _uploadPhoto(
    String fotoPath,
    Map<String, dynamic> payload,
    String token,
  ) async {
    final file = File(payload['local_path'] as String);
    if (!await file.exists()) {
      return ApiResponse(422, {
        'message': 'File foto tidak ditemukan di perangkat — mungkin sudah '
            'terhapus dari penyimpanan.',
      });
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
      return ApiResponse(503, {'message': 'Unggah foto ke penyimpanan gagal (HTTP $status).'});
    }

    return _apiClient.request('POST', fotoPath,
        body: {'object_key': sign.body['object_key']}, token: token);
  }

  /// Puts a report's rejected queue items back in line (user tapped
  /// "Kirim ulang"), then drains the queue.
  Future<SyncRunResult> retryFailed(String clientId) async {
    await SQLiteManager.instance.resetFailedSyncItems(clientId);
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    if (local != null) {
      await SQLiteManager.instance.upsertLocalReport(
        clientId: clientId,
        payloadJson: local.payloadJson ?? '{}',
        syncStatus: 'pending',
      );
    }
    return runSyncQueue();
  }

  /// Returns true when this was the report's last open job.
  Future<bool> _applySuccess(
    String clientId,
    String endpoint,
    Map<String, dynamic> request,
    Map<String, dynamic> data,
  ) async {
    final local = await SQLiteManager.instance.getLocalReport(clientId);
    if (local == null) return false;
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
    return open == 0;
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
