import '/backend/sqlite/queries/sqlite_row.dart';
import 'package:sqflite/sqflite.dart';

Future<List<T>> _readQuery<T>(
  Database database,
  String query,
  T Function(Map<String, dynamic>) create,
) =>
    database.rawQuery(query).then((r) => r.map((e) => create(e)).toList());

/// BEGIN GETALLLOCALREPORTS
Future<List<GetAllLocalReportsRow>> performGetAllLocalReports(
  Database database,
) {
  final query = '''
SELECT * FROM local_reports ORDER BY updated_at DESC;
''';
  return _readQuery(database, query, (d) => GetAllLocalReportsRow(d));
}

class GetAllLocalReportsRow extends SqliteRow {
  GetAllLocalReportsRow(Map<String, dynamic> data) : super(data);

  String get clientId => data['client_id'] as String;
  /// Server UUID (backend v4). Read via toString() because SQLite's INTEGER
  /// column affinity keeps it TEXT only as long as it isn't numeric.
  String? get serverId => data['server_id']?.toString();
  String? get reportCode => data['report_code'] as String?;
  String? get payloadJson => data['payload_json'] as String?;
  String get syncStatus => data['sync_status'] as String;
  String? get lastError => data['last_error'] as String?;
  int get retryCount => data['retry_count'] as int;
  String get createdAt => data['created_at'] as String;
  String? get updatedAt => data['updated_at'] as String?;
}

/// END GETALLLOCALREPORTS

/// BEGIN GETLOCALREPORT
Future<GetAllLocalReportsRow?> performGetLocalReport(
  Database database,
  String clientId,
) async {
  final rows = await database.query(
    'local_reports',
    where: 'client_id = ?',
    whereArgs: [clientId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return GetAllLocalReportsRow(rows.first);
}

/// END GETLOCALREPORT

/// BEGIN GETMASTERCACHE
class MasterCacheEntry {
  MasterCacheEntry({required this.dataJson, required this.fetchedAt});

  final String dataJson;
  final DateTime fetchedAt;
}

Future<MasterCacheEntry?> performGetMasterCache(
  Database database,
  String cacheKey,
) async {
  final rows = await database.query(
    'master_cache',
    columns: ['data_json', 'fetched_at'],
    where: 'cache_key = ?',
    whereArgs: [cacheKey],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  final row = rows.first;
  return MasterCacheEntry(
    dataJson: row['data_json'] as String,
    fetchedAt: DateTime.parse(row['fetched_at'] as String),
  );
}

/// END GETMASTERCACHE

/// BEGIN GETPENDINGSYNCQUEUE
Future<int> performCountOpenSyncItems(Database database, String clientId) async {
  final rows = await database.rawQuery(
    "SELECT COUNT(*) AS c FROM sync_queue WHERE client_id = ? AND status IN ('pending', 'failed')",
    [clientId],
  );
  return (rows.first['c'] as int?) ?? 0;
}

Future<Set<String>> performGetClientIdsWithFailedSyncItems(Database database) async {
  final rows = await database.rawQuery(
    "SELECT DISTINCT client_id FROM sync_queue WHERE status = 'failed'",
  );
  return rows.map((r) => r['client_id'] as String).toSet();
}

/// The job the server rejected for [clientId] (at most one: later jobs of
/// that report wait behind it).
Future<GetPendingSyncQueueRow?> performGetFailedSyncItem(
  Database database,
  String clientId,
) async {
  final rows = await database.query(
    'sync_queue',
    where: "client_id = ? AND status = 'failed'",
    whereArgs: [clientId],
    orderBy: 'created_at ASC, id ASC',
    limit: 1,
  );
  return rows.isEmpty ? null : GetPendingSyncQueueRow(rows.first);
}

Future<List<GetPendingSyncQueueRow>> performGetPendingSyncQueue(
  Database database,
) {
  final query = '''
SELECT * FROM sync_queue WHERE status = 'pending' ORDER BY created_at ASC, id ASC;
''';
  return _readQuery(database, query, (d) => GetPendingSyncQueueRow(d));
}

class GetPendingSyncQueueRow extends SqliteRow {
  GetPendingSyncQueueRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get clientId => data['client_id'] as String;
  String get endpoint => data['endpoint'] as String;
  String get method => data['method'] as String;
  String get payloadJson => data['payload_json'] as String;
  String get status => data['status'] as String;
  int get retryCount => data['retry_count'] as int;
  String? get lastError => data['last_error'] as String?;
  String get createdAt => data['created_at'] as String;
}

/// END GETPENDINGSYNCQUEUE
