import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sehat_satli/app_state.dart';
import 'package:sehat_satli/backend/sqlite/sqlite_manager.dart';
import 'package:sehat_satli/core/network/api_client.dart';
import 'package:sehat_satli/data/repositories/report_repository.dart';
import 'package:sehat_satli/data/repositories/sync_repository.dart';

/// Covers tasks.md Fase 7's "uji alur offline: isi laporan tanpa koneksi →
/// kirim otomatis saat online kembali, tidak duplikat (verifikasi
/// client_id)" item — exercising the real SQLite schema (via
/// `sqflite_common_ffi`, since plain `flutter test` has no platform channel
/// for the real `sqflite`) and the FIFO drain algorithm from CLAUDE.md §5.2,
/// with a fake `http.Client` standing in for the network.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = p.join(await databaseFactory.getDatabasesPath(), 'sehatsatli.db');
    await databaseFactory.deleteDatabase(dbPath);
    await SQLiteManager.initialize();
  });

  setUp(() async {
    final db = SQLiteManager.instance.database;
    await db.delete('local_reports');
    await db.delete('sync_queue');
    await db.delete('master_cache');
  });

  tearDown(() {
    FFAppState.reset();
  });

  test(
      'submit() retried while offline does not duplicate the local_reports '
      'row, though sync_queue gets one entry per attempt (server dedupes by '
      'client_id on drain, not the local queue)', () async {
    final offlineClient = MockClient((request) async {
      throw const SocketException('offline');
    });
    final repo = ReportRepository(apiClient: ApiClient(client: offlineClient));
    const clientId = 'test-client-offline-retry';
    final payload = {'report_date': '2026-01-01', 'description': 'test'};

    final first =
        await repo.submit(clientId: clientId, payload: payload, token: 'tok');
    final second =
        await repo.submit(clientId: clientId, payload: payload, token: 'tok');

    expect(first.status, ReportSubmitStatus.queuedOffline);
    expect(second.status, ReportSubmitStatus.queuedOffline);

    final localRows = await SQLiteManager.instance.getAllLocalReports();
    expect(localRows.where((r) => r.clientId == clientId), hasLength(1));

    final queued = await SQLiteManager.instance.getPendingSyncQueue();
    expect(queued.where((r) => r.clientId == clientId), hasLength(2));
  });

  test(
      'runSyncQueue() marks a successfully-synced item done and updates '
      'local_reports to synced with the server id/report code', () async {
    const clientId = 'test-client-sync-success';
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode({'client_id': clientId}),
      syncStatus: 'pending',
    );
    final queueId = await SQLiteManager.instance.enqueueSyncItem(
      clientId: clientId,
      endpoint: 'api/general-reports/saveGeneralReportMobile',
      payloadJson: jsonEncode({'client_id': clientId}),
    );

    final client = MockClient((request) async {
      if (request.url.path.contains('ping')) {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': 42, 'report_code': 'REP-42'},
        }),
        200,
      );
    });

    FFAppState().accessToken = 'tok';
    await SyncRepository(apiClient: ApiClient(client: client)).runSyncQueue();

    final stillPending = await SQLiteManager.instance.getPendingSyncQueue();
    expect(stillPending.where((r) => r.id == queueId), isEmpty);

    final localRows = await SQLiteManager.instance.getAllLocalReports();
    final row = localRows.firstWhere((r) => r.clientId == clientId);
    expect(row.syncStatus, 'synced');
    expect(row.serverId, 42);
    expect(row.reportCode, 'REP-42');
  });

  test(
      'runSyncQueue() stops draining after the first network failure '
      '(CLAUDE.md §5.2: break the loop, do not burn through the rest of the '
      'queue) instead of marking every item failed', () async {
    const firstClientId = 'test-client-network-fail-1';
    const secondClientId = 'test-client-network-fail-2';
    for (final clientId in [firstClientId, secondClientId]) {
      await SQLiteManager.instance.upsertLocalReport(
        clientId: clientId,
        payloadJson: jsonEncode({'client_id': clientId}),
        syncStatus: 'pending',
      );
      await SQLiteManager.instance.enqueueSyncItem(
        clientId: clientId,
        endpoint: 'api/general-reports/saveGeneralReportMobile',
        payloadJson: jsonEncode({'client_id': clientId}),
      );
    }

    final client = MockClient((request) async {
      if (request.url.path.contains('ping')) {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      throw const SocketException('connection dropped mid-sync');
    });

    FFAppState().accessToken = 'tok';
    await SyncRepository(apiClient: ApiClient(client: client)).runSyncQueue();

    final queued = await SQLiteManager.instance.getPendingSyncQueue();
    expect(queued, hasLength(2)); // both still pending, neither marked failed

    final first = queued.firstWhere((r) => r.clientId == firstClientId);
    final second = queued.firstWhere((r) => r.clientId == secondClientId);
    expect(first.retryCount, 1); // the one attempt that failed
    expect(second.retryCount, 0); // never even attempted — loop broke first
  });

  test(
      'runSyncQueue() leaves a _resolveIdFromClientId item pending and never '
      'posts it while its report\'s server_id is still unknown', () async {
    const clientId = 'test-client-unresolved-dependent';
    // No local_reports row at all yet — the Tab 1 create hasn't even been
    // queued, let alone synced, so server_id can't possibly be known.
    final queueId = await SQLiteManager.instance.enqueueSyncItem(
      clientId: clientId,
      endpoint: 'api/general-reports/saveVerify',
      payloadJson: jsonEncode({
        'verified_date': '2026-01-01',
        'client_id': clientId,
        '_sectionKey': 'verification',
        '_resolveIdFromClientId': true,
      }),
    );

    var postCount = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('ping')) {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      postCount++;
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    FFAppState().accessToken = 'tok';
    await SyncRepository(apiClient: ApiClient(client: client)).runSyncQueue();

    expect(postCount, 0); // never attempted — server id unresolved
    final stillQueued = await SQLiteManager.instance.getPendingSyncQueue();
    final row = stillQueued.firstWhere((r) => r.id == queueId);
    expect(row.status, 'pending');
    expect(row.retryCount, 0); // untouched, not counted as a failed attempt
  });

  test(
      'runSyncQueue() resolves a dependent section item in the same drain '
      'pass once its report\'s create item (queued earlier) succeeds',
      () async {
    const clientId = 'test-client-same-pass-resolve';
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode({'client_id': clientId, 'report_date': '2026-01-01'}),
      syncStatus: 'pending',
    );
    // Enqueued first (create), so FIFO drains it before the dependent item.
    await SQLiteManager.instance.enqueueSyncItem(
      clientId: clientId,
      endpoint: 'api/general-reports/save',
      payloadJson: jsonEncode({'client_id': clientId, 'report_date': '2026-01-01'}),
    );
    await SQLiteManager.instance.enqueueSyncItem(
      clientId: clientId,
      endpoint: 'api/general-reports/saveVerify',
      payloadJson: jsonEncode({
        'verified_date': '2026-01-01',
        'client_id': clientId,
        '_sectionKey': 'verification',
        '_resolveIdFromClientId': true,
      }),
    );

    dynamic verifyRequestBody;
    final client = MockClient((request) async {
      if (request.url.path.contains('ping')) {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      if (request.url.path.contains('saveVerify')) {
        verifyRequestBody = jsonDecode(request.body);
        return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
      }
      // The create call — returns the new server id.
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': 77, 'report_code': 'REP-77'},
        }),
        200,
      );
    });

    FFAppState().accessToken = 'tok';
    await SyncRepository(apiClient: ApiClient(client: client)).runSyncQueue();

    final stillPending = await SQLiteManager.instance.getPendingSyncQueue();
    expect(stillPending.where((r) => r.clientId == clientId), isEmpty);
    expect(verifyRequestBody, isNotNull);
    expect(verifyRequestBody['id'], 77); // resolved from the create's server id
    expect(verifyRequestBody.containsKey('_resolveIdFromClientId'), isFalse);

    final localRows = await SQLiteManager.instance.getAllLocalReports();
    final row = localRows.firstWhere((r) => r.clientId == clientId);
    expect(row.serverId, 77);
    expect(row.reportCode, 'REP-77');
  });

  test(
      'runSyncQueue() merges a section-endpoint success into payload_json '
      'without erasing other sections or nulling an already-known server_id',
      () async {
    const clientId = 'test-client-section-merge';
    await SQLiteManager.instance.upsertLocalReport(
      clientId: clientId,
      payloadJson: jsonEncode({
        'client_id': clientId,
        'report_date': '2026-01-01',
        'lab': {'final_diagnosis': 'existing lab data'},
      }),
      syncStatus: 'synced',
      serverId: 10,
      reportCode: 'REP-10',
    );
    await SQLiteManager.instance.enqueueSyncItem(
      clientId: clientId,
      endpoint: 'api/general-reports/saveVerify',
      payloadJson: jsonEncode({
        'verified_date': '2026-01-01',
        'client_id': clientId,
        'id': 10,
        '_sectionKey': 'verification',
      }),
    );

    // Response omits both `id` and `report_code` — must not null out the
    // already-known ones.
    final client = MockClient((request) async {
      if (request.url.path.contains('ping')) {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response(
        jsonEncode({'success': true, 'data': {'message': 'ok'}}),
        200,
      );
    });

    FFAppState().accessToken = 'tok';
    await SyncRepository(apiClient: ApiClient(client: client)).runSyncQueue();

    final localRows = await SQLiteManager.instance.getAllLocalReports();
    final row = localRows.firstWhere((r) => r.clientId == clientId);
    expect(row.serverId, 10); // preserved, not nulled out
    expect(row.reportCode, 'REP-10'); // preserved, not nulled out

    final payload = jsonDecode(row.payloadJson!) as Map<String, dynamic>;
    expect(payload['lab']['final_diagnosis'], 'existing lab data'); // survived
    expect(payload['verification']['verified_date'], '2026-01-01'); // merged in
    expect(payload['report_date'], '2026-01-01'); // top-level fields survived too
  });
}
