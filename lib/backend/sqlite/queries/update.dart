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

/// Inserts a new row or replaces the payload/status of an existing one,
/// keeping `created_at`, and keeping `server_id`/`report_code`/`last_error`
/// unless new values are passed.
Future<void> performUpsertLocalReport(
  Database database, {
  required String clientId,
  required String payloadJson,
  required String syncStatus,
  String? serverId,
  String? reportCode,
  String? lastError,
}) async {
  final now = DateTime.now().toIso8601String();
  final existing = await database.query(
    'local_reports',
    where: 'client_id = ?',
    whereArgs: [clientId],
    limit: 1,
  );
  final previous = existing.isNotEmpty ? existing.first : const <String, Object?>{};
  await database.insert(
    'local_reports',
    {
      'client_id': clientId,
      'server_id': serverId ?? previous['server_id'],
      'report_code': reportCode ?? previous['report_code'],
      'payload_json': payloadJson,
      'sync_status': syncStatus,
      // `failed` keeps its rejection until retried; `pending` may carry why
      // the last attempt didn't go through (offline, server down).
      'last_error': switch (syncStatus) {
        'failed' => lastError ?? previous['last_error'],
        'pending' => lastError,
        _ => null,
      },
      'retry_count': 0,
      'created_at': previous['created_at'] ?? now,
      'updated_at': now,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> performDeleteLocalReport(
  Database database,
  String clientId,
) async {
  await database.delete(
    'sync_queue',
    where: 'client_id = ?',
    whereArgs: [clientId],
  );
  await database.delete(
    'local_reports',
    where: 'client_id = ?',
    whereArgs: [clientId],
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

Future<void> performResetFailedSyncItems(Database database, String clientId) =>
    database.update(
      'sync_queue',
      {'status': 'pending'},
      where: "client_id = ? AND status = 'failed'",
      whereArgs: [clientId],
    );

/// Replaces a rejected job's request with corrected data and puts it back
/// in line, keeping its place in the queue.
Future<void> performReplaceSyncItemPayload(
  Database database, {
  required int id,
  required String payloadJson,
}) =>
    database.update(
      'sync_queue',
      {
        'payload_json': payloadJson,
        'status': 'pending',
        'retry_count': 0,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
