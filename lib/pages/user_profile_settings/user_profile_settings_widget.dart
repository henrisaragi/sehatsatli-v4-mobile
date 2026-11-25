import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/action_card/action_card_widget.dart';
import '/components/button/button_widget.dart';
import '/components/profile_header/profile_header_widget.dart';
import '/components/settings_item/settings_item_widget.dart';
import '/components/storage_stat/storage_stat_widget.dart';
import '/components/switch_component/switch_component_widget.dart';
import '/components/training_mode_banner.dart';
import '../../core/network/api_client.dart';
import '/data/models/user_profile_fields.dart';
import '/data/repositories/auth_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserProfileSettingsModel());
    _refreshProfile();
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

  /// NIP, jabatan and UPT live on the UPT registration, not on `GET user`.
  RegistrationStatusResult? _registration;

  Map<String, dynamic>? _currentUserMap() {
    final user = FFAppState().currentUser;
    return user is Map ? Map<String, dynamic>.from(user) : null;
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final fields = UserProfileFields(_currentUserMap());

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 0.0,
                height: 0.0,
              ),
              TrainingModeBanner(),
              Expanded(
                child: Container(
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        wrapWithModel(
                          model: _model.profileHeaderModel,
                          updateCallback: () => safeSetState(() {}),
                          child: ProfileHeaderWidget(
                            name: fields.name,
                            role: _registration?.jabatan ?? fields.role,
                            nip: _registration?.nip ?? '-',
                            institution:
                                _registration?.upt?['nama']?.toString(),
                          ),
                        ),
                        Container(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Storage Management',
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                          lineHeight: 1.35,
                                        ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      borderRadius: BorderRadius.circular(12.0),
                                      shape: BoxShape.rectangle,
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Container(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  flex: 1,
                                                  child: wrapWithModel(
                                                    model: _model
                                                        .storageStatModel1,
                                                    updateCallback: () =>
                                                        safeSetState(() {}),
                                                    child: StorageStatWidget(
                                                      label: 'Local Reports',
                                                      value: '12 Drafts',
                                                      progress: 0.4,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondary,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 1,
                                                  child: wrapWithModel(
                                                    model: _model
                                                        .storageStatModel2,
                                                    updateCallback: () =>
                                                        safeSetState(() {}),
                                                    child: StorageStatWidget(
                                                      label: 'Photo Cache',
                                                      value: '128 MB',
                                                      progress: 0.65,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                    ),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 24.0)),
                                            ),
                                            Divider(
                                              height: 16.0,
                                              thickness: 1.0,
                                              indent: 0.0,
                                              endIndent: 0.0,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .alternate,
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Database Status',
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelSmall
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelSmall
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelSmall
                                                                    .fontStyle,
                                                                lineHeight:
                                                                    1.27,
                                                              ),
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          width: 8.0,
                                                          height: 8.0,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .success,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        9999.0),
                                                            shape: BoxShape
                                                                .rectangle,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Healthy & Encrypted',
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodySmall
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodySmall
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .success,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                                lineHeight:
                                                                    1.38,
                                                              ),
                                                        ),
                                                      ].divide(
                                                          SizedBox(width: 4.0)),
                                                    ),
                                                  ].divide(
                                                      SizedBox(height: 4.0)),
                                                ),
                                                wrapWithModel(
                                                  model: _model.buttonModel1,
                                                  updateCallback: () =>
                                                      safeSetState(() {}),
                                                  child: ButtonWidget(
                                                    icon: Icon(
                                                      LucideIcons.hardDrive,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      size: 24.0,
                                                    ),
                                                    iconPresent: true,
                                                    iconEndPresent: false,
                                                    content: 'Optimize DB',
                                                    variant: 'outline',
                                                    size: 'small',
                                                    fullWidth: false,
                                                    loading: false,
                                                    disabled: false,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ].divide(SizedBox(height: 24.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ].divide(SizedBox(height: 16.0)),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              32.0, 0.0, 32.0, 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16.0, 24.0, 16.0, 8.0),
                                  child: Container(
                                    child: Text(
                                      'Account',
                                      style: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelLarge
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                            lineHeight: 1.33,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16.0, 24.0, 16.0, 8.0),
                                  child: Container(
                                    child: Text(
                                      'System & Sync',
                                      style: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelLarge
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                            lineHeight: 1.33,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              wrapWithModel(
                                model: _model.settingsItemModel3,
                                updateCallback: () => safeSetState(() {}),
                                child: SettingsItemWidget(
                                  onTap: () => context
                                      .goNamed(SyncManagerWidget.routeName),
                                  iconBg: FlutterFlowTheme.of(context)
                                      .surfaceVariant,
                                  icon: Icon(
                                    LucideIcons.refreshCw,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  title: 'Sync Manager',
                                  subtitle:
                                      'Manage queue and background sync intervals',
                                ),
                              ),
                              wrapWithModel(
                                model: _model.settingsItemModel4,
                                updateCallback: () => safeSetState(() {}),
                                child: SettingsItemWidget(
                                  onTap: () => showSnackbar(
                                      context, 'Offline Maps coming soon'),
                                  iconBg: FlutterFlowTheme.of(context)
                                      .surfaceVariant,
                                  icon: Icon(
                                    LucideIcons.cloudDownload,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  title: 'Offline Maps',
                                  subtitle:
                                      'Download regional maps for offline field work',
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  shape: BoxShape.rectangle,
                                ),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      24.0, 16.0, 24.0, 16.0),
                                  child: Container(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 40.0,
                                          height: 40.0,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                            shape: BoxShape.rectangle,
                                          ),
                                          alignment:
                                              AlignmentDirectional(0.0, 0.0),
                                          child: Icon(
                                            LucideIcons.wifiOff,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 20.0,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: wrapWithModel(
                                            model: _model.switchModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: SwitchComponentWidget(
                                              label: 'Strict Offline Mode',
                                              labelPresent: true,
                                              variant: 'Android',
                                              active: FFAppState()
                                                  .strictOfflineMode,
                                            ),
                                          ),
                                        ),
                                      ].divide(SizedBox(width: 16.0)),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16.0, 24.0, 16.0, 8.0),
                                  child: Container(
                                    child: Text(
                                      'Support',
                                      style: FlutterFlowTheme.of(context)
                                          .labelLarge
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelLarge
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                            lineHeight: 1.33,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              wrapWithModel(
                                model: _model.settingsItemModel5,
                                updateCallback: () => safeSetState(() {}),
                                child: SettingsItemWidget(
                                  onTap: () => showSnackbar(
                                      context, 'Help Center coming soon'),
                                  iconBg: FlutterFlowTheme.of(context)
                                      .surfaceVariant,
                                  icon: Icon(
                                    LucideIcons.circleHelp,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  title: 'Help Center',
                                  subtitle:
                                      'Documentation and system usage guides',
                                ),
                              ),
                              wrapWithModel(
                                model: _model.settingsItemModel6,
                                updateCallback: () => safeSetState(() {}),
                                child: SettingsItemWidget(
                                  onTap: () => context.pushNamed(
                                      PrivacyPolicyWidget.routeName),
                                  iconBg: FlutterFlowTheme.of(context)
                                      .surfaceVariant,
                                  icon: Icon(
                                    LucideIcons.fileText,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  title: 'Privacy Policy',
                                  subtitle:
                                      'Data handling and encryption standards',
                                ),
                              ),
                              Container(
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      24.0, 32.0, 24.0, 32.0),
                                  child: Container(
                                    child: Container(
                                      alignment: AlignmentDirectional(0.0, 0.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              await AuthRepository().logout();
                                              FFAppState().clearSession();
                                              if (!mounted) return;
                                              context.goNamed(
                                                  SplashAuthWidget.routeName);
                                            },
                                            child: wrapWithModel(
                                              model: _model.buttonModel2,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ButtonWidget(
                                                icon: Icon(
                                                  LucideIcons.logOut,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  size: 24.0,
                                                ),
                                                iconPresent: true,
                                                iconEndPresent: false,
                                                content: 'Sign Out',
                                                variant: 'destructive',
                                                size: 'medium',
                                                fullWidth: true,
                                                loading: false,
                                                disabled: false,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'SehatSatli v2.4.0-stable',
                                            style: FlutterFlowTheme.of(context)
                                                .labelSmall
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelSmall
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelSmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                  lineHeight: 1.27,
                                                ),
                                          ),
                                        ].divide(SizedBox(height: 16.0)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ].divide(SizedBox(height: 4.0)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MainBottomNavWidget(currentTab: MainTab.profil),
      ),
    );
  }
}
