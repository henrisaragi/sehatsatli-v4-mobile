import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '/data/repositories/notification_repository.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// FCM push notifications (Android + iOS) and the unread badge count.
///
/// The server sends a `notification` payload with `data: {jenis, laporan_id}`.
/// Tapping a push opens that laporan; a tap that cold-starts the app is kept in
/// [takePendingLaporanId] until the dashboard is up (after login/splash).
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final NotificationRepository _repository = NotificationRepository();

  /// Drives the badge on the dashboard bell.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  String? _pendingLaporanId;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get _supported => !kIsWeb;

  String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Call once from `main()` after Firebase is initialized.
  Future<void> init() async {
    if (!_supported) return;
    final messaging = FirebaseMessaging.instance;
    // iOS shows the system banner in the foreground too; Android doesn't, so
    // [_onForegroundMessage] shows a snackbar there instead.
    await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => openLaporan(message.data['laporan_id']));
    _pendingLaporanId = (await messaging.getInitialMessage())?.data['laporan_id'];
  }

  /// Asks for notification permission and registers this device's FCM token
  /// for the logged-in user. Best-effort: push is never required to use the app.
  Future<void> registerForUser(String accessToken) async {
    if (!_supported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final fcmToken = await _fcmToken();
      if (fcmToken != null) {
        await _repository.registerDevice(fcmToken, _platform, token: accessToken);
      }
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((fcmToken) {
        final token = FFAppState().accessToken;
        if (token != null) {
          _repository.registerDevice(fcmToken, _platform, token: token).catchError((_) {});
        }
      });
    } catch (_) {
      // No network, no Play Services, APNs not ready… retried on next launch.
    }
  }

  /// Stops pushes to this device for the user signing out ([accessToken] is
  /// the outgoing session's token).
  Future<void> unregisterForUser(String accessToken) async {
    unreadCount.value = 0;
    if (!_supported) return;
    try {
      final fcmToken = await _fcmToken();
      if (fcmToken != null) {
        await _repository.unregisterDevice(fcmToken, token: accessToken);
      }
    } catch (_) {
      // Best-effort; the server also drops tokens FCM reports as dead.
    }
  }

  Future<void> refreshUnreadCount(String accessToken) async {
    try {
      final page = await _repository.fetchPage(token: accessToken, perPage: 1);
      if (page != null) unreadCount.value = page.unreadCount;
    } catch (_) {
      // Offline: keep the last known count.
    }
  }

  String? takePendingLaporanId() {
    final id = _pendingLaporanId;
    _pendingLaporanId = null;
    return id;
  }

  /// Opens the laporan detail, or keeps it pending while nobody is logged in.
  void openLaporan(String? laporanId) {
    if (laporanId == null || laporanId.isEmpty) return;
    final context = appNavigatorKey.currentContext;
    if (context == null || FFAppState().accessToken == null) {
      _pendingLaporanId = laporanId;
      return;
    }
    context.pushNamed(
      FullReportWidget.routeName,
      queryParameters: {'reportId': serializeParam(laporanId, ParamType.String)}.withoutNulls,
    );
  }

  Future<String?> _fcmToken() async {
    final messaging = FirebaseMessaging.instance;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // getToken() throws until APNs has handed iOS its device token.
      if (await messaging.getAPNSToken() == null) {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (await messaging.getAPNSToken() == null) return null;
      }
    }
    return messaging.getToken();
  }

  void _onForegroundMessage(RemoteMessage message) {
    unreadCount.value += 1;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final context = appNavigatorKey.currentContext;
    final notification = message.notification;
    if (context == null || notification == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(notification.title ?? notification.body ?? 'Notifikasi baru'),
      action: SnackBarAction(
        label: 'Lihat',
        onPressed: () => openLaporan(message.data['laporan_id']),
      ),
    ));
  }
}
