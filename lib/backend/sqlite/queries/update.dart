import 'package:sqflite/sqflite.dart';

Future<void> performUpsertMasterCache(
  Database database,
  String cacheKey,
  String dataJson,
) =>
    database.insert(
      'master_cache',
      {
        'cache_key': cacheKey,
        'data_json': dataJson,
        'fetched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

Future<void> performUpsertLocalReport(
  Database database, {
  required String clientId,
  required String payloadJson,
  required String syncStatus,
  int? serverId,
  String? reportCode,
}) async {
  final now = DateTime.now().toIso8601String();
  final existing = await database.query(
    'local_reports',
    columns: ['created_at'],
    where: 'client_id = ?',
    whereArgs: [clientId],
    limit: 1,
  );
  await database.insert(
    'local_reports',
    {
      'client_id': clientId,
      'server_id': serverId,
      'report_code': reportCode,
      'payload_json': payloadJson,
      'sync_status': syncStatus,
      'retry_count': 0,
      'created_at': existing.isNotEmpty ? existing.first['created_at'] : now,
      'updated_at': now,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<int> performEnqueueSyncItem(
  Database database, {
  required String clientId,
  required String endpoint,
  required String payloadJson,
  String method = 'POST',
}) =>
    database.insert('sync_queue', {
      'client_id': clientId,
      'endpoint': endpoint,
      'method': method,
      'payload_json': payloadJson,
      'status': 'pending',
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

Future<void> performMarkSyncItemStatus(
  Database database, {
  required int id,
  required String status,
  String? lastError,
}) =>
    database.update(
      'sync_queue',
      {
        'status': status,
        if (lastError != null) 'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

Future<void> performIncrementSyncItemRetry(
  Database database, {
  required int id,
  required String lastError,
}) =>
    database.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [lastError, id],
    );
