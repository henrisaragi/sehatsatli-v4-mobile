import 'package:flutter/foundation.dart';

import '/backend/sqlite/init.dart';
import 'queries/read.dart';
import 'queries/update.dart';

import 'package:sqflite/sqflite.dart';
export 'queries/read.dart';
export 'queries/update.dart';

class SQLiteManager {
  SQLiteManager._();

  static SQLiteManager? _instance;
  static SQLiteManager get instance => _instance ??= SQLiteManager._();

  static late Database _database;
  Database get database => _database;

  static Future initialize() async {
    if (kIsWeb) {
      return;
    }
    _database = await initializeDatabase('sehatsatli');
  }

  /// START READ QUERY CALLS

  Future<List<GetAllLocalReportsRow>> getAllLocalReports() =>
      performGetAllLocalReports(
        _database,
      );

  Future<GetAllLocalReportsRow?> getLocalReport(String clientId) =>
      performGetLocalReport(_database, clientId);

  Future<MasterCacheEntry?> getMasterCache(String cacheKey) =>
      performGetMasterCache(
        _database,
        cacheKey,
      );

  Future<List<GetPendingSyncQueueRow>> getPendingSyncQueue() =>
      performGetPendingSyncQueue(_database);

  /// END READ QUERY CALLS

  /// START UPDATE QUERY CALLS

  Future<void> upsertMasterCache(String cacheKey, String dataJson) =>
      performUpsertMasterCache(_database, cacheKey, dataJson);

  Future<void> upsertLocalReport({
    required String clientId,
    required String payloadJson,
    required String syncStatus,
    int? serverId,
    String? reportCode,
  }) =>
      performUpsertLocalReport(
        _database,
        clientId: clientId,
        payloadJson: payloadJson,
        syncStatus: syncStatus,
        serverId: serverId,
        reportCode: reportCode,
      );

  Future<int> enqueueSyncItem({
    required String clientId,
    required String endpoint,
    required String payloadJson,
    String method = 'POST',
  }) =>
      performEnqueueSyncItem(
        _database,
        clientId: clientId,
        endpoint: endpoint,
        payloadJson: payloadJson,
        method: method,
      );

  Future<void> markSyncItemDone(int id) =>
      performMarkSyncItemStatus(_database, id: id, status: 'done');

  Future<void> markSyncItemFailed(int id, String error) =>
      performMarkSyncItemStatus(
          _database, id: id, status: 'failed', lastError: error);

  Future<void> incrementSyncItemRetry(int id, String error) =>
      performIncrementSyncItemRetry(_database, id: id, lastError: error);

  /// END UPDATE QUERY CALLS
}
