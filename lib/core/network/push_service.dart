import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '/data/repositories/notification_repository.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// FCM push notifications (Android + iOS) and the unread badge count.
///
/// The server sends a `notification` payload with `data: {jenis, laporan_id}`.
/// Pushes pop up as heads-up banners: in the background Android posts them on
/// the high-importance [_channel] (the manifest's default FCM channel); in the
/// foreground Android posts nothing itself, so we show them on that channel
/// via flutter_local_notifications, while iOS shows its own banner.
/// Tapping a push opens that laporan; a tap that cold-starts the app is kept in
/// [takePendingLaporanId] until the dashboard is up (after login/splash).
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  final NotificationRepository _repository = NotificationRepository();

  /// Drives the badge on the dashboard bell.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Must match `default_notification_channel_id` in AndroidManifest.xml.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'laporan',
    'Notifikasi laporan',
    description: 'Pembaruan laporan dan tahap pemeriksaan',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  String? _pendingLaporanId;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get _supported => !kIsWeb;

  String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Call once from `main()` after Firebase is initialized.
  Future<void> init() async {
    if (!_supported) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    if (_isAndroid) await _initLocalNotifications();
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => openLaporan(message.data['laporan_id']));
    _pendingLaporanId ??= (await messaging.getInitialMessage())?.data['laporan_id'];
  }

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _initLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notification'),
      ),
      onDidReceiveNotificationResponse: (response) => openLaporan(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    // A foreground banner tapped after the app was killed cold-starts it.
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingLaporanId = launch?.notificationResponse?.payload;
    }
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
    final notification = message.notification;
    if (!_isAndroid || notification == null) return;
    _local.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: notification.title,
      body: notification.body,
      payload: message.data['laporan_id'],
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notification',
          color: const Color(0xFF17B273),
          styleInformation: BigTextStyleInformation(notification.body ?? ''),
        ),
      ),
    );
  }
}
