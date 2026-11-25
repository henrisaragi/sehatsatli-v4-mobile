import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sehat_satli/app_state.dart';
import 'package:sehat_satli/backend/sqlite/init.dart';
import 'package:sehat_satli/backend/sqlite/sqlite_manager.dart';
import 'package:sehat_satli/core/network/api_client.dart';
import 'package:sehat_satli/data/repositories/report_repository.dart';

/// Offline-first laporan flow against backend v4 (CLAUDE.md §5.2): real
/// SQLite schema via `sqflite_common_ffi`, fake `http.Client` for the server.
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
    FFAppState().accessToken = 'tok';
  });

  tearDown(FFAppState.reset);

  const createPayload = {'spesies_id': 'spesies-1', 'kelompok_umur': 'dewasa'};
  const investigasi = {
    'tanggal_kejadian': '2026-11-20',
    'jumlah_sakit': 2,
    'kronologi': 'Lesu sejak dua hari lalu.',
    'tindak_lanjut': 'Dipisahkan dari kandang utama.',
    'kesimpulan_awal': 'suspek_penyakit',
    'latitude': -6.9,
    'longitude': 107.6,
  };

  http.Response json(int status, Object body) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  /// Fake v4 server; [handler] answers API calls, `/up` always succeeds.
  MockClient server(Future<http.Response> Function(http.Request request) handler) =>
      MockClient((request) async {
        if (request.url.path.endsWith('/up')) return http.Response('', 200);
        return handler(request);
      });

  Future<Map<String, dynamic>> localPayload(String clientId) async {
    final row = await SQLiteManager.instance.getLocalReport(clientId);
    return jsonDecode(row!.payloadJson!) as Map<String, dynamic>;
  }

  test('offline: create + investigasi stay queued in order, report is pending', () async {
    final offline = MockClient((_) async => throw const SocketException('offline'));
    final repo = ReportRepository(apiClient: ApiClient(client: offline));

    final result = await repo.createWithInvestigasi(
      clientId: 'c-offline',
      createPayload: createPayload,
      investigasi: investigasi,
    );

    expect(result.status, ReportSubmitStatus.queuedOffline);
    final queue = await SQLiteManager.instance.getPendingSyncQueue();
    expect(queue.map((q) => '${q.method} ${q.endpoint}'),
        ['POST laporan', 'PUT laporan/{laporan}/investigasi']);
    expect(jsonDecode(queue.first.payloadJson)['client_uuid'], 'c-offline');

    final row = await SQLiteManager.instance.getLocalReport('c-offline');
    expect(row!.syncStatus, 'pending');
    expect((await localPayload('c-offline'))['tahap'], 'verifikasi_dokter');
    expect((await localPayload('c-offline'))['tahap_server'], isNull);
  });

  test('online: create resolves the server UUID used by the next stage', () async {
    final requests = <String>[];
    final client = server((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.method == 'POST' && request.url.path.endsWith('/api/laporan')) {
        expect(jsonDecode(request.body)['client_uuid'], 'c-online');
        return json(201, {'id': 'uuid-1', 'tahap': 'investigasi'});
      }
      return json(200, {'id': 'uuid-1', 'tahap': 'verifikasi_dokter'});
    });
    final repo = ReportRepository(apiClient: ApiClient(client: client));

    final result = await repo.createWithInvestigasi(
      clientId: 'c-online',
      createPayload: createPayload,
      investigasi: investigasi,
    );

    expect(result.status, ReportSubmitStatus.sent);
    expect(requests, [
      'POST /api-v4/api/laporan',
      'PUT /api-v4/api/laporan/uuid-1/investigasi',
    ]);
    final row = await SQLiteManager.instance.getLocalReport('c-online');
    expect(row!.syncStatus, 'synced');
    expect(row.serverId, 'uuid-1');
    expect((await localPayload('c-online'))['tahap'], 'verifikasi_dokter');
    expect((await localPayload('c-online'))['tahap_server'], 'verifikasi_dokter');
    expect(await SQLiteManager.instance.getPendingSyncQueue(), isEmpty);
  });

  test('a rejected create blocks its later stages until the user retries', () async {
    var rejectCreate = true;
    final requests = <String>[];
    final client = server((request) async {
      requests.add('${request.method} ${request.url.path}');
      if (request.url.path.endsWith('/api/laporan')) {
        return rejectCreate
            ? json(422, {
                'message': 'The given data was invalid.',
                'errors': {
                  'spesies_id': ['The selected spesies id is invalid.'],
                },
              })
            : json(201, {'id': 'uuid-2', 'tahap': 'investigasi'});
      }
      return json(200, {'id': 'uuid-2', 'tahap': 'verifikasi_dokter'});
    });
    final repo = ReportRepository(apiClient: ApiClient(client: client));

    final first = await repo.createWithInvestigasi(
      clientId: 'c-rejected',
      createPayload: createPayload,
      investigasi: investigasi,
    );

    expect(first.status, ReportSubmitStatus.failed);
    expect(first.message, 'The selected spesies id is invalid.');
    expect(requests, ['POST /api-v4/api/laporan']); // investigasi never sent
    expect((await localPayload('c-rejected'))['tahap_server'], isNull);

    rejectCreate = false;
    final retried = await repo.retry('c-rejected');

    expect(retried.status, ReportSubmitStatus.sent);
    expect(requests.last, 'PUT /api-v4/api/laporan/uuid-2/investigasi');
    final row = await SQLiteManager.instance.getLocalReport('c-rejected');
    expect(row!.syncStatus, 'synced');
    expect(row.lastError, isNull);
  });

  test('network failure stops the drain and only bumps the attempted item', () async {
    for (final clientId in ['c-net-1', 'c-net-2']) {
      await ReportRepository(
        apiClient: ApiClient(client: MockClient((_) async => throw const SocketException('x'))),
      ).createWithInvestigasi(
        clientId: clientId,
        createPayload: createPayload,
        investigasi: investigasi,
      );
    }

    final client = server((_) async => throw const SocketException('dropped mid-sync'));
    await ReportRepository(apiClient: ApiClient(client: client)).retry('c-net-1');

    final queue = await SQLiteManager.instance.getPendingSyncQueue();
    expect(queue, hasLength(4)); // nothing marked failed
    expect(queue.first.retryCount, 1);
    expect(queue.skip(1).every((q) => q.retryCount == 0), isTrue);
  });

  test('server error (5xx) is retried later, not marked failed', () async {
    final client = server((_) async => json(503, {'message': 'Service Unavailable'}));
    final result = await ReportRepository(apiClient: ApiClient(client: client))
        .createWithInvestigasi(
      clientId: 'c-503',
      createPayload: createPayload,
      investigasi: investigasi,
    );

    expect(result.status, ReportSubmitStatus.queuedOffline);
    final queue = await SQLiteManager.instance.getPendingSyncQueue();
    expect(queue, hasLength(2));
    expect(queue.first.retryCount, 1);
  });

  test('photo: sign-upload, raw PUT to object storage, then register', () async {
    final photo = File(p.join(Directory.systemTemp.path, 'foto-test.jpg'))
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    final requests = <String>[];
    final client = server((request) async {
      requests.add('${request.method} ${request.url.host}${request.url.path}');
      final path = request.url.path;
      if (path.endsWith('/api/laporan')) return json(201, {'id': 'uuid-3', 'tahap': 'investigasi'});
      if (path.endsWith('/investigasi')) return json(200, {'id': 'uuid-3', 'tahap': 'verifikasi_dokter'});
      if (path.endsWith('/foto/sign-upload')) {
        expect(jsonDecode(request.body), {'content_type': 'image/jpeg'});
        return json(200, {
          'method': 'PUT',
          'url': 'https://s3.example.test/sehatsatli/laporan/uuid-3/a.jpg?X-Amz-Signature=x',
          'headers': {'Content-Type': 'image/jpeg'},
          'object_key': 'laporan/uuid-3/a.jpg',
        });
      }
      if (request.url.host == 's3.example.test') {
        expect(request.bodyBytes, [0xFF, 0xD8, 0xFF]);
        expect(request.headers['Content-Type'], 'image/jpeg');
        return http.Response('', 200);
      }
      expect(jsonDecode(request.body), {'object_key': 'laporan/uuid-3/a.jpg'});
      return json(201, {'id': 'foto-1', 'object_key': 'laporan/uuid-3/a.jpg', 'url': 'https://signed'});
    });

    final result = await ReportRepository(apiClient: ApiClient(client: client))
        .createWithInvestigasi(
      clientId: 'c-foto',
      createPayload: createPayload,
      investigasi: investigasi,
      photoPaths: [photo.path],
    );

    expect(result.status, ReportSubmitStatus.sent);
    expect(requests.skip(2), [
      'POST sehatsatli.ksdae.kehutanan.go.id/api-v4/api/laporan/uuid-3/foto/sign-upload',
      'PUT s3.example.test/sehatsatli/laporan/uuid-3/a.jpg',
      'POST sehatsatli.ksdae.kehutanan.go.id/api-v4/api/laporan/uuid-3/foto',
    ]);
    final payload = await localPayload('c-foto');
    expect(payload['foto_lokal'], isEmpty);
    expect((payload['foto'] as List).single['id'], 'foto-1');
  });

  test('upgrading the v1 database keeps unsynced old reports as legacy', () async {
    final path = p.join(await databaseFactory.getDatabasesPath(), 'upgrade_test.db');
    await databaseFactory.deleteDatabase(path);
    final v1 = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE local_reports (client_id TEXT PRIMARY KEY, '
                'server_id INTEGER, report_code TEXT, payload_json TEXT NOT NULL, '
                'sync_status TEXT NOT NULL, last_error TEXT, retry_count INTEGER NOT NULL '
                'DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT)');
            await db.execute("CREATE TABLE sync_queue (id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "client_id TEXT NOT NULL, endpoint TEXT NOT NULL, method TEXT NOT NULL DEFAULT "
                "'POST', payload_json TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', "
                "retry_count INTEGER NOT NULL DEFAULT 0, last_error TEXT, created_at TEXT NOT NULL)");
            await db.execute('CREATE TABLE master_cache (cache_key TEXT PRIMARY KEY, '
                'data_json TEXT NOT NULL, fetched_at TEXT NOT NULL)');
          },
        ));
    for (final (id, status) in [('old-pending', 'pending'), ('old-synced', 'synced')]) {
      await v1.insert('local_reports', {
        'client_id': id,
        'payload_json': '{}',
        'sync_status': status,
        'created_at': '2026-08-01',
      });
    }
    await v1.insert('sync_queue', {
      'client_id': 'old-pending',
      'endpoint': 'api/general-reports/save',
      'payload_json': '{}',
      'created_at': '2026-08-01',
    });
    await v1.close();

    final upgraded = await initializeDatabase('upgrade_test');
    final reports = await upgraded.query('local_reports');
    final queue = await upgraded.query('sync_queue');
    await upgraded.close();

    expect(reports.map((r) => '${r['client_id']}:${r['sync_status']}'), ['old-pending:legacy']);
    expect(queue.single['status'], 'failed');
  });
}
