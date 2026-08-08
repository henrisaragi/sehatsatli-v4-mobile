import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_response_helper.dart';

class MasterRepository {
  MasterRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  static const Duration _cacheTtl = Duration(hours: 24);

  static const Map<String, String> _endpointsByCacheKey = {
    'masters': ApiEndpoints.masters,
    'location_user': ApiEndpoints.locationUser,
    'diseases': ApiEndpoints.diseasesGetAll,
    'species': ApiEndpoints.speciesGetAll,
    'upts': ApiEndpoints.uptsGetAll,
  };

  /// Fetches every master dataset and writes it to `master_cache`, skipping
  /// any key whose cache is still within TTL unless [force] is set.
  ///
  /// Safe to call fire-and-forget — network/parse failures are swallowed so
  /// the app just keeps using whatever's already cached (offline-first: a
  /// failed refresh must never block the caller or wipe existing data).
  Future<void> refreshAll({required String token, bool force = false}) async {
    for (final entry in _endpointsByCacheKey.entries) {
      try {
        if (!force && await _isFresh(entry.key)) continue;
        final response = await _apiClient.post(entry.value, token: token);
        if (!isApiSuccess(response)) continue;
        final data = response['data'] ?? response;
        await _writeCache(entry.key, jsonEncode(data));
      } catch (_) {
        // Leave whatever's already cached untouched.
      }
    }
  }

  /// The live `masters` response wraps every option group inside
  /// `data.options.*` (e.g. `{options: {upt_type: [...], case_types: [...]},
  /// trained: ...}`), not flat at the top level — confirmed against
  /// production, see revisi.md bug note #1. [refreshAll] caches the raw
  /// response as-is; unwrap it here, once, so every consumer (existing and
  /// future) gets the option lists directly without needing to know about
  /// the wrapping.
  Future<dynamic> getCachedMasters() async {
    final cached = await _readCached('masters');
    if (cached is Map && cached['options'] is Map) {
      return cached['options'];
    }
    return cached;
  }
  Future<dynamic> getCachedLocationUser() => _readCached('location_user');
  Future<dynamic> getCachedDiseases() => _readCached('diseases');
  Future<dynamic> getCachedSpecies() => _readCached('species');
  Future<dynamic> getCachedUpts() => _readCached('upts');

  /// Reads the locally-cached `species/getAll` list (already fetched &
  /// persisted to `master_cache` by [refreshAll], per CLAUDE.md §10.3 —
  /// dropdowns must read from local DB, not fire a fresh network call) and
  /// filters it down to `protected == true` (design-system.md §4: `Species`
  /// has a `protected` bool column). Used to populate the "Satwa Dilindungi"
  /// picker in the report form's Spesies step.
  Future<List<Map<String, dynamic>>> getCachedProtectedSpecies() async {
    final all = _asMapList(await getCachedSpecies());
    return all.where((s) => _isTruthy(s['protected'])).toList();
  }

  static List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      for (final key in const ['species', 'data']) {
        final v = data[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  static bool _isTruthy(dynamic v) => v == true || v == 1 || v == '1';

  /// `dokter/getAll` is a public endpoint (no token) per API_ENDPOINTS.md §2,
  /// so it's kept separate from [refreshAll]'s token-gated loop — fetched
  /// lazily the first time the verification form needs the vet list, then
  /// cached the same way as the other lookups.
  Future<dynamic> getCachedDokter() async {
    final cached = await _readCached('dokter');
    if (cached != null) return cached;
    try {
      final response = await _apiClient.post(ApiEndpoints.dokterGetAll);
      if (!isApiSuccess(response)) return null;
      final data = response['data'] ?? response;
      await _writeCache('dokter', jsonEncode(data));
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _readCached(String cacheKey) async {
    // sqflite has no web implementation — the master cache simply doesn't
    // persist there; callers should rely on a fresh refreshAll() instead.
    if (kIsWeb) return null;
    try {
      final entry = await SQLiteManager.instance.getMasterCache(cacheKey);
      if (entry == null) return null;
      return jsonDecode(entry.dataJson);
    } catch (_) {
      return null;
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
