import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> initializeDatabase(String databaseName) async {
  final databasesPath = await getDatabasesPath();
  final path = join(databasesPath, '$databaseName.db');
  return openDatabase(
    path,
    version: 2,
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        // v4.2.0 moved the `api/` segment into ApiEndpoints.baseUrl. Queued
        // rows store the endpoint path, so strip the old prefix or they'd be
        // sent to `.../api/api/...` and fail.
        await db.execute(
          "UPDATE sync_queue SET endpoint = substr(endpoint, 5) "
          "WHERE endpoint LIKE 'api/%'",
        );
      }
    },
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE local_reports (
          client_id       TEXT PRIMARY KEY,
          server_id       INTEGER,
          report_code     TEXT,
          payload_json    TEXT NOT NULL,
          sync_status     TEXT NOT NULL,
          last_error      TEXT,
          retry_count     INTEGER NOT NULL DEFAULT 0,
          created_at      TEXT NOT NULL,
          updated_at      TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE sync_queue (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          client_id       TEXT NOT NULL,
          endpoint        TEXT NOT NULL,
          method          TEXT NOT NULL DEFAULT 'POST',
          payload_json    TEXT NOT NULL,
          status          TEXT NOT NULL DEFAULT 'pending',
          retry_count     INTEGER NOT NULL DEFAULT 0,
          last_error      TEXT,
          created_at      TEXT NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE master_cache (
          cache_key       TEXT PRIMARY KEY,
          data_json       TEXT NOT NULL,
          fetched_at      TEXT NOT NULL
        );
      ''');
    },
  );
}
