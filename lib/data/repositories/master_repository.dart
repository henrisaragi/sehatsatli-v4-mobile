import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';

/// Read-only master data (species, diseases) cached in `master_cache` so the
/// report forms work with zero signal (CLAUDE.md §10.3).
class MasterRepository {
  MasterRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const Duration _cacheTtl = Duration(hours: 24);

  static const Map<String, String> _endpointsByCacheKey = {
    'spesies': ApiEndpoints.spesies,
    'penyakit': ApiEndpoints.penyakit,
  };

  /// Downloads every page of each master list into `master_cache`, skipping
  /// lists still within TTL unless [force] is set. Safe fire-and-forget: a
  /// failed refresh keeps whatever was cached before.
  Future<void> refreshAll({required String token, bool force = false}) async {
    for (final entry in _endpointsByCacheKey.entries) {
      try {
        if (!force && await _isFresh(entry.key)) continue;
        final rows = await _fetchAllPages(entry.value, token);
        if (rows != null) await _writeCache(entry.key, jsonEncode(rows));
      } catch (_) {
        // Leave whatever's already cached untouched.
      }
    }
  }

  /// Species: `{id, scientific_name, local_name, status_perlindungan,
  /// family: {nama_ilmiah}, taksa: {nama}}`.
  Future<List<Map<String, dynamic>>> getCachedSpesies() => _readCached('spesies');

  /// Diseases: `{id, nama, prioritas, zoonosis, alert}`.
  Future<List<Map<String, dynamic>>> getCachedPenyakit() => _readCached('penyakit');

  Future<List<Map<String, dynamic>>?> _fetchAllPages(String path, String token) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final response = await _apiClient.request('GET', path,
          query: {'page': page, 'per_page': 100}, token: token);
      if (!response.isSuccess) return null;
      final data = response.body['data'];
      if (data is List) {
        rows.addAll(data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
      }
      final lastPage = response.body['last_page'] as int? ?? page;
      if (page >= lastPage) return rows;
      page++;
    }
  }

  Future<List<Map<String, dynamic>>> _readCached(String cacheKey) async {
    // sqflite has no web implementation — nothing persists there.
    if (kIsWeb) return [];
    try {
      final entry = await SQLiteManager.instance.getMasterCache(cacheKey);
      if (entry == null) return [];
      final decoded = jsonDecode(entry.dataJson);
      return decoded is List
          ? decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> _isFresh(String cacheKey) async {
    if (kIsWeb) return false;
    try {
      final entry = await SQLiteManager.instance.getMasterCache(cacheKey);
      if (entry == null) return false;
      return DateTime.now().difference(entry.fetchedAt) < _cacheTtl;
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeCache(String cacheKey, String dataJson) async {
    if (kIsWeb) return;
    await SQLiteManager.instance.upsertMasterCache(cacheKey, dataJson);
  }
}
