import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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
import '../../data/repositories/user_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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

  String? _localPhotoPath;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserProfileSettingsModel());
    _refreshProfile();
  }

  /// Best-effort refresh against `users/getOne`, so the page shows more
  /// current data than the login-response snapshot when possible. Silently
  /// keeps the existing `FFAppState().currentUser` on any failure (offline,
  /// missing id, server rejection) — this is a nice-to-have refresh, not a
  /// hard requirement per CLAUDE.md's offline-first principle.
  Future<void> _refreshProfile() async {
    final token = FFAppState().accessToken;
    final fields = UserProfileFields(_currentUserMap());
    if (token == null || fields.id == null) return;
    try {
      final fresh =
          await UserRepository().fetchOne(id: fields.id, token: token);
      if (fresh == null || !mounted) return;
      setState(() => FFAppState().currentUser = fresh);
      await AuthRepository().updatePersistedUser(fresh);
    } on ApiNetworkException {
      // Offline — keep showing the cached snapshot.
    }
  }

  Map<String, dynamic>? _currentUserMap() {
    final user = FFAppState().currentUser;
    return user is Map ? Map<String, dynamic>.from(user) : null;
  }

  Future<void> _pickAndUploadPhoto(UserProfileFields fields) async {
    final token = FFAppState().accessToken;
    if (token == null || fields.id == null) {
      showSnackbar(
          context, 'Data pengguna tidak lengkap, tidak bisa unggah foto');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_rounded),
              title: Text('Ambil Foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded),
              title: Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 1280, imageQuality: 70);
    if (picked == null) return;

    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      quality: 70,
      minWidth: 512,
      minHeight: 512,
    );
    final localPath = compressed?.path ?? picked.path;

    if (!mounted) return;
    setState(() {
      _localPhotoPath = localPath;
      _uploadingPhoto = true;
    });

    final bytes = await File(localPath).readAsBytes();
    final base64File = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    try {
      final result = await UserRepository()
          .uploadPhoto(id: fields.id, base64File: base64File, token: token);
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      if (!result.success) {
        showSnackbar(context, result.message ?? 'Gagal mengunggah foto');
        return;
      }
      if (result.user != null) {
        final merged = {...(_currentUserMap() ?? {}), ...result.user!};
        setState(() => FFAppState().currentUser = merged);
        await AuthRepository().updatePersistedUser(merged);
      }
      showSnackbar(context, 'Foto profil berhasil diperbarui');
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      showSnackbar(context, 'Tidak bisa mengunggah foto — periksa koneksi');
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    var isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Ganti Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password baru',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (controller.text.isEmpty) {
                        setDialogState(
                            () => errorText = 'Password tidak boleh kosong');
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      final result = await AuthRepository()
                          .changePassword(controller.text);
                      if (result.success) {
                        Navigator.of(dialogContext).pop();
                        if (context.mounted) {
                          showSnackbar(context, 'Password berhasil diubah');
                        }
                      } else {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText =
                              result.message ?? 'Gagal mengubah password';
                        });
                      }
                    },
              child: Text('Simpan'),
            ),
          ],
        ),
      ),
    );
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
        body: Container(
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
                            role: fields.role,
                            nip: fields.nip,
                            institution: fields.institution.isEmpty
                                ? null
                                : fields.institution,
                            photoUrl: fields.photoUrl,
                            localPhotoPath: _localPhotoPath,
                            uploadingPhoto: _uploadingPhoto,
                            onTapAvatar: () => _pickAndUploadPhoto(fields),
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
                                                      Icons.storage_rounded,
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
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: wrapWithModel(
                                      model: _model.editProfileCardModel,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ActionCardWidget(
                                        onTap: () async {
                                          await context.pushNamed(
                                              EditProfileWidget.routeName);
                                          if (mounted) safeSetState(() {});
                                        },
                                        tone: FlutterFlowTheme.of(context)
                                            .primary,
                                        icon: Icon(
                                          Icons.person_outline_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        title: 'Edit Profile',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: wrapWithModel(
                                      model: _model.securityCardModel,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ActionCardWidget(
                                        onTap: () =>
                                            _showChangePasswordDialog(context),
                                        tone: FlutterFlowTheme.of(context)
                                            .tertiary,
                                        icon: Icon(
                                          Icons.security_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        title: 'Security',
                                      ),
                                    ),
                                  ),
                                ].divide(SizedBox(width: 16.0)),
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
                                      .pushNamed(SyncManagerWidget.routeName),
                                  iconBg: FlutterFlowTheme.of(context)
                                      .surfaceVariant,
                                  icon: Icon(
                                    Icons.sync_rounded,
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
                                model: _model.communityReportListSettingsModel,
                                updateCallback: () => safeSetState(() {}),
                                child: SettingsItemWidget(
                                  onTap: () => context.pushNamed(
                                      CommunityReportListWidget.routeName),
                                  iconBg: FlutterFlowTheme.of(context)
                                      .surfaceVariant,
                                  icon: Icon(
                                    Icons.campaign_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  title: 'Laporan Masyarakat',
                                  subtitle:
                                      'Lihat laporan cepat dari warga tanpa akun',
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
                                    Icons.cloud_download_rounded,
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
                                            Icons.wifi_off_rounded,
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
                                    Icons.help_outline_rounded,
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
                                  onTap: () => showSnackbar(
                                      context, 'Privacy Policy coming soon'),
                                  iconBg: FlutterFlowTheme.of(context)
                                      .surfaceVariant,
                                  icon: Icon(
                                    Icons.description_rounded,
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
                                              FFAppState().accessToken = null;
                                              FFAppState().currentUser = null;
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
                                                  Icons.logout_rounded,
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
