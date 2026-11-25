import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/sqlite/sqlite_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  String _historySearchQuery = '';
  String get historySearchQuery => _historySearchQuery;
  set historySearchQuery(String value) {
    _historySearchQuery = value;
  }

  String _historyFilter = 'Semua';
  String get historyFilter => _historyFilter;
  set historyFilter(String value) {
    _historyFilter = value;
  }

  bool _strictOfflineMode = true;
  bool get strictOfflineMode => _strictOfflineMode;
  set strictOfflineMode(bool value) {
    _strictOfflineMode = value;
  }

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  set isSyncing(bool value) {
    _isSyncing = value;
  }

  String? _accessToken;
  String? get accessToken => _accessToken;
  set accessToken(String? value) {
    _accessToken = value;
  }

  dynamic _currentUser;
  dynamic get currentUser => _currentUser;
  set currentUser(dynamic value) {
    _currentUser = value;
  }

  /// RBAC attributes per CLAUDE.md §7 — computed defensively from the raw
  /// login-response user map since the exact response shape (int/bool/string
  /// encoding of these flags) hasn't been confirmed against a live response.
  dynamic _userField(String key) =>
      _currentUser is Map ? _currentUser[key] : null;

  bool _truthy(dynamic v) => v == true || v == 1 || v == '1';

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool get isDoctor => _truthy(_userField('is_doctor'));
  bool get headsUpt => _truthy(_userField('heads_upt'));
  bool get trainingMode => _truthy(_userField('training_mode'));
  bool get allNotification => _truthy(_userField('all_notification'));
  int? get uptId => _asInt(_userField('upt_id'));

  /// `reset_password` is set by an admin creating a new account with a
  /// default/temporary password — design-system.md §backend audit confirms
  /// this exact field name (unlike the other RBAC flags above, this one
  /// isn't a guess) is what the app must use to force a password change
  /// before letting the user into the rest of the app. See
  /// `ForcePasswordChangeWidget` + the router redirect in nav.dart.
  bool get mustResetPassword => _truthy(_userField('reset_password'));
}
