import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '/backend/sqlite/sqlite_manager.dart';
import '/components/button/button_widget.dart';
import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/profile_header/profile_header_widget.dart';
import '/components/settings_item/settings_item_widget.dart';
import '/components/training_mode_banner.dart';
import '/core/network/api_client.dart';
import '/data/models/user_profile_fields.dart';
import '/data/repositories/auth_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/main.dart';
import 'user_profile_settings_model.dart';
export 'user_profile_settings_model.dart';

class UserProfileSettingsWidget extends StatefulWidget {
  const UserProfileSettingsWidget({super.key});

  static String routeName = 'UserProfileSettings';
  static String routePath = '/userProfileSettings';

  @override
  State<UserProfileSettingsWidget> createState() =>
      _UserProfileSettingsWidgetState();
}

class _UserProfileSettingsWidgetState extends State<UserProfileSettingsWidget> {
  late UserProfileSettingsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// NIP, jabatan and UPT live on the UPT registration, not on `GET user`.
  RegistrationStatusResult? _registration;

  /// Local reports queued or rejected; null until counted (or on web).
  int? _unsentCount;
  String? _version;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserProfileSettingsModel());
    _refreshProfile();
    _countUnsent();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  /// Best-effort refresh against `GET user`; keeps the cached snapshot when
  /// offline (CLAUDE.md offline-first).
  Future<void> _refreshProfile() async {
    final token = FFAppState().accessToken;
    if (token == null) return;
    try {
      final auth = AuthRepository();
      final fresh = await auth.fetchCurrentUser(token);
      final registration = await auth.fetchRegistrationStatus(token);
      if (!mounted) return;
      setState(() {
        if (fresh != null) FFAppState().currentUser = fresh;
        if (registration.exists) _registration = registration;
      });
    } on ApiNetworkException {
      // Offline — keep showing the cached snapshot.
    }
  }

  Future<void> _countUnsent() async {
    if (kIsWeb) return;
    try {
      final rows = await SQLiteManager.instance.getAllLocalReports();
      final count = rows
          .where((r) => r.syncStatus == 'pending' || r.syncStatus == 'failed')
          .length;
      if (mounted) setState(() => _unsentCount = count);
    } catch (_) {
      // sqflite unavailable — just omit the count.
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await AuthRepository().logout();
    FFAppState().clearSession();
    if (!mounted) return;
    context.goNamed(SplashAuthWidget.routeName);
  }

  Map<String, dynamic>? _currentUserMap() {
    final user = FFAppState().currentUser;
    return user is Map ? Map<String, dynamic>.from(user) : null;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final fields = UserProfileFields(_currentUserMap());
    final unsent = _unsentCount;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TrainingModeBanner(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: 24.0),
                children: [
                  wrapWithModel(
                    model: _model.profileHeaderModel,
                    updateCallback: () => safeSetState(() {}),
                    child: ProfileHeaderWidget(
                      name: fields.name,
                      role: _registration?.jabatan ?? fields.role,
                      nip: _registration?.nip ?? '-',
                      institution: _registration?.upt?['nama']?.toString(),
                    ),
                  ),
                  _section('Tampilan', [
                    Padding(
                      padding: EdgeInsets.all(12.0),
                      child: _ThemeModeSelector(),
                    ),
                  ]),
                  _section('Sinkronisasi', [
                    SettingsItemWidget(
                      icon: LucideIcons.refreshCw,
                      iconColor: theme.primary,
                      title: 'Sync Manager',
                      subtitle: unsent == null
                          ? 'Antrean laporan yang akan dikirim'
                          : unsent == 0
                              ? 'Semua laporan sudah terkirim'
                              : '$unsent laporan menunggu dikirim',
                      onTap: () => context.goNamed(SyncManagerWidget.routeName),
                    ),
                  ]),
                  _section('Informasi', [
                    SettingsItemWidget(
                      icon: LucideIcons.shieldCheck,
                      title: 'Kebijakan Privasi',
                      subtitle: 'Pengelolaan dan keamanan data',
                      onTap: () =>
                          context.pushNamed(PrivacyPolicyWidget.routeName),
                    ),
                  ]),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.0, 32.0, 20.0, 0.0),
                    child: InkWell(
                      onTap: _loggingOut ? null : _logout,
                      borderRadius: BorderRadius.circular(10.0),
                      child: wrapWithModel(
                        model: _model.logoutButtonModel,
                        updateCallback: () => safeSetState(() {}),
                        child: ButtonWidget(
                          icon: Icon(LucideIcons.logOut,
                              color: theme.onError, size: 20.0),
                          iconPresent: true,
                          content: 'Keluar',
                          variant: 'destructive',
                          size: 'medium',
                          fullWidth: true,
                          loading: _loggingOut,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.0),
                  Text(
                    _version == null ? 'SehatSatli' : 'SehatSatli v$_version',
                    textAlign: TextAlign.center,
                    style: theme.bodySmall.override(
                        color: theme.secondaryText, letterSpacing: 0.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavWidget(currentTab: MainTab.profil),
    );
  }

  /// Uppercase caption over a bordered card holding [children], separated
  /// by hairline dividers.
  Widget _section(String title, List<Widget> children) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              title.toUpperCase(),
              style: theme.labelSmall.override(
                font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                color: theme.secondaryText,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Material(
            color: theme.secondaryBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: theme.alternate),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children.divide(
                  Divider(height: 1.0, thickness: 1.0, color: theme.alternate)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Terang / Gelap / Sistem pill selector; persisted by [MyApp.setThemeMode].
class _ThemeModeSelector extends StatefulWidget {
  @override
  State<_ThemeModeSelector> createState() => _ThemeModeSelectorState();
}

class _ThemeModeSelectorState extends State<_ThemeModeSelector> {
  static const _options = [
    (ThemeMode.light, LucideIcons.sun, 'Terang'),
    (ThemeMode.dark, LucideIcons.moon, 'Gelap'),
    (ThemeMode.system, LucideIcons.smartphone, 'Sistem'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final current = MyApp.of(context).themeMode;
    return Container(
      padding: EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          for (final (mode, icon, label) in _options)
            Expanded(
              child: Semantics(
                button: true,
                selected: mode == current,
                child: InkWell(
                  // setState too: Gelap → Sistem on a dark phone changes no
                  // inherited theme, so nothing else would rebuild this.
                  onTap: () =>
                      setState(() => setDarkModeSetting(context, mode)),
                  borderRadius: BorderRadius.circular(8.0),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    decoration: BoxDecoration(
                      color: mode == current
                          ? theme.secondaryBackground
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                          color: mode == current
                              ? theme.alternate
                              : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: 16.0,
                            color: mode == current
                                ? theme.primary
                                : theme.secondaryText),
                        SizedBox(width: 6.0),
                        Text(
                          label,
                          style: theme.labelLarge.override(
                            color: mode == current
                                ? theme.primaryText
                                : theme.secondaryText,
                            letterSpacing: 0.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
