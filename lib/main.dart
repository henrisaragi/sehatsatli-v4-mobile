import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import '/backend/sqlite/sqlite_manager.dart';
import 'backend/firebase/firebase_config.dart';
import '/core/network/api_client.dart';
import '/core/network/push_service.dart';
import '/core/storage/secure_storage.dart';
import '/data/repositories/sync_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'flutter_flow/flutter_flow_util.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'flutter_flow/nav/nav.dart';
import 'index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase();
  try {
    await PushService.instance.init();
  } catch (_) {
    // Push is optional; a failure here must never keep the app from starting.
  }

  await SQLiteManager.initialize();
  await FlutterFlowTheme.initialize();

  final appState = FFAppState(); // Initialize FFAppState
  await appState.initializePersistedState();

  // Any API response with HTTP 401 clears the session and bounces to login,
  // even if the request happened on a page other than the login screen.
  ApiClient.onUnauthorized = () {
    FFAppState().clearSession();
    SecureStorage().deleteToken();
    SecureStorage().deleteUserJson();
    final context = appNavigatorKey.currentContext;
    if (context != null) {
      context.goNamed(SplashAuthWidget.routeName);
    }
  };

  // Drain the offline outbox as soon as connectivity comes back — the
  // manual "Sync Now" button in Sync Manager is the other trigger.
  Connectivity().onConnectivityChanged.listen((results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (hasConnection) {
      SyncRepository().runSyncQueue();
    }
  });

  runApp(ChangeNotifierProvider(
    create: (context) => appState,
    child: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  // This widget is the root of your application.
  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = FlutterFlowTheme.themeMode;

  late AppStateNotifier _appStateNotifier;
  late GoRouter _router;
  String getRoute([RouteMatch? routeMatch]) {
    final RouteMatch lastMatch =
        routeMatch ?? _router.routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : _router.routerDelegate.currentConfiguration;
    return matchList.uri.path;
  }

  List<String> getRouteStack() =>
      _router.routerDelegate.currentConfiguration.matches
          .map((e) => getRoute(e))
          .toList();
  @override
  void initState() {
    super.initState();

    _appStateNotifier = AppStateNotifier.instance;
    _router = createRouter(_appStateNotifier);
  }

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) => safeSetState(() {
        _themeMode = mode;
        FlutterFlowTheme.saveThemeMode(mode);
      });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SehatSatli',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('id', ''),
      supportedLocales: const [Locale('id', '')],
      theme: FlutterFlowTheme.materialTheme(Brightness.light),
      darkTheme: FlutterFlowTheme.materialTheme(Brightness.dark),
      themeMode: _themeMode,
      routerConfig: _router,
    );
  }
}
