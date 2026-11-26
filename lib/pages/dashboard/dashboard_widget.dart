import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/action_card/action_card_widget.dart';
import '/components/button/button_widget.dart';
import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/report_card/report_card_widget.dart';
import '/components/training_mode_banner.dart';
import '/core/utils/error_bottom_sheet.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/network/api_client.dart';
import '../../core/network/push_service.dart';
import '../../data/models/laporan_fields.dart';
import '../../data/models/report_list_item.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/sync_repository.dart';
import 'dashboard_model.dart';
export 'dashboard_model.dart';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({super.key});

  static String routeName = 'Dashboard';
  static String routePath = '/dashboard';

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget> {
  late DashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  List<GetAllLocalReportsRow> _localReports = [];
  List<Map<String, dynamic>> _serverReports = [];
  DashboardSummary? _summary;

  /// Reports waiting at each stage, keyed by `tahap`; missing while offline.
  final Map<String, int> _tahapCounts = {};
  bool _isLoading = true;

  /// Whether `laporan/saya` answered; otherwise Beranda falls back to the
  /// local copies of synced reports.
  bool _serverLoaded = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardModel());
    _load();
    // A push tapped before login/splash finished opens once the dashboard is up.
    final pendingLaporanId = PushService.instance.takePendingLaporanId();
    if (pendingLaporanId != null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => PushService.instance.openLaporan(pendingLaporanId));
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    if (!kIsWeb) {
      try {
        _localReports = await SQLiteManager.instance.getAllLocalReports();
      } catch (_) {
        // sqflite unavailable (e.g. web) — local drafts just won't show.
        _localReports = [];
      }
    }

    final token = FFAppState().accessToken;
    if (token != null) {
      try {
        final result = await ReportRepository().fetchReports(
          page: 1,
          token: token,
          scope: ReportListScope.mine,
        );
        _serverReports = result.reports;
        _serverLoaded = result.errorMessage == null;
      } on ApiNetworkException {
        _serverReports = [];
        _serverLoaded = false;
      }
      _summary = await DashboardRepository().fetchRingkasan(token: token);
      await _loadTahapCounts(token);
      PushService.instance.refreshUnreadCount(token);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  static const _shortcutTahap = ['investigasi', 'verifikasi_dokter'];

  /// Totals only (`per_page=1`), same scope as the list the shortcut opens.
  Future<void> _loadTahapCounts(String token) async {
    final results = await Future.wait(_shortcutTahap.map((tahap) async {
      try {
        final result = await ReportRepository().fetchReports(
          page: 1,
          perPage: 1,
          token: token,
          scope: ReportListScope.entitas,
          tahap: tahap,
        );
        return result.errorMessage == null ? result.total : null;
      } on ApiNetworkException {
        return null;
      }
    }));
    _tahapCounts.clear();
    for (var i = 0; i < _shortcutTahap.length; i++) {
      final count = results[i];
      if (count != null) _tahapCounts[_shortcutTahap[i]] = count;
    }
  }

  Future<void> _openTahapList(String tahap) async {
    await context.pushNamed(
      ReportHistoryWidget.routeName,
      queryParameters:
          {'tahap': serializeParam(tahap, ParamType.String)}.withoutNulls,
    );
    if (mounted) _load();
  }

  /// Queued reports only — drafts and legacy rows are never sent.
  List<GetAllLocalReportsRow> get _pendingLocal => _localReports
      .where((r) => r.syncStatus == 'pending' || r.syncStatus == 'failed')
      .toList();

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final result = await SyncRepository().runSyncQueue();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    await _load();
    if (!mounted) return;
    final message = result.summary(draftCount: 0);
    if (result.hasProblem) {
      showErrorBottomSheet(context, message,
          title: 'Ada laporan yang belum terkirim',
          icon: LucideIcons.cloudOff,
          warning: result.rejected.isEmpty);
    } else {
      showSnackbar(context, message);
    }
  }

  List<ReportListItem> get _recentItems => ReportListItem.merge(
        _localReports,
        _serverReports,
        serverLoaded: _serverLoaded,
        userId: (FFAppState().currentUser as Map?)?['id']?.toString(),
      ).take(5).toList();

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingLocal.length;
    final recentItems = _recentItems;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                border: Border(
                    bottom: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SehatSatli',
                            style: FlutterFlowTheme.of(context)
                                .headlineSmall
                                .override(
                                  font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800),
                                  color: FlutterFlowTheme.of(context).primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Text(
                            'Wildlife Health Surveillance',
                            style: FlutterFlowTheme.of(context)
                                .labelSmall
                                .override(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText),
                          ),
                        ],
                      ),
                      _notificationBell(),
                    ],
                  ),
                ),
              ),
            ),
            TrainingModeBanner(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (pendingCount > 0) _syncBanner(pendingCount),
                            if (_summary != null) _summaryCard(),
                            _quickActions(),
                            _recentReportsSection(recentItems),
                          ].divide(SizedBox(height: 24.0)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: MainBottomNavWidget(
          currentTab: MainTab.beranda,
          onQuickReportClosed: _load,
        ),
      ),
    );
  }

  Widget _notificationBell() {
    final theme = FlutterFlowTheme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: PushService.instance.unreadCount,
      builder: (context, unread, _) => Semantics(
        button: true,
        label: unread > 0 ? 'Notifikasi, $unread belum dibaca' : 'Notifikasi',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            FlutterFlowIconButton(
              borderRadius: 8.0,
              buttonSize: 44.0,
              fillColor: Colors.transparent,
              icon:
                  Icon(LucideIcons.bell, color: theme.primaryText, size: 26.0),
              onPressed: () async {
                await context.pushNamed(NotificationsWidget.routeName);
                final token = FFAppState().accessToken;
                if (token != null)
                  PushService.instance.refreshUnreadCount(token);
              },
            ),
            if (unread > 0)
              Positioned(
                right: 4.0,
                top: 4.0,
                child: IgnorePointer(
                  child: Container(
                    constraints: BoxConstraints(minWidth: 18.0),
                    height: 18.0,
                    padding: EdgeInsets.symmetric(horizontal: 5.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.error,
                      borderRadius: BorderRadius.circular(999.0),
                      border: Border.all(
                          color: theme.secondaryBackground, width: 1.5),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: theme.bodySmall.override(
                        color: Colors.white,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _syncBanner(int pendingCount) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).accent2,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: FlutterFlowTheme.of(context).secondary30),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(LucideIcons.cloudAlert,
                color: FlutterFlowTheme.of(context).secondary, size: 20.0),
            SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pendingCount Laporan Menunggu Dikirim',
                    style: FlutterFlowTheme.of(context).labelLarge.override(
                          font: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          color: FlutterFlowTheme.of(context).secondary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Terhubung ke internet untuk mengunggah data',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: FlutterFlowTheme.of(context).secondary),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.0),
            InkWell(
              onTap: _isSyncing ? null : _syncNow,
              child: wrapWithModel(
                model: _model.buttonModel1,
                updateCallback: () => safeSetState(() {}),
                child: ButtonWidget(
                  content: 'Kirim',
                  variant: 'secondary',
                  size: 'small',
                  fullWidth: false,
                  loading: _isSyncing,
                  disabled: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    final theme = FlutterFlowTheme.of(context);
    final summary = _summary!;
    Widget row(String label, int total) => Padding(
          padding: EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium.override(
                        color: theme.primaryText, letterSpacing: 0.0)),
              ),
              SizedBox(width: 12.0),
              Text('$total',
                  style: theme.bodyMedium.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      color: theme.primaryText,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.0)),
            ],
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.alternate),
      ),
      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: theme.accent3,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                alignment: Alignment.center,
                child:
                    Icon(LucideIcons.barChart3, color: theme.info, size: 20.0),
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total laporan nasional',
                        style: theme.bodySmall.override(
                            color: theme.secondaryText, letterSpacing: 0.0)),
                    Text('${summary.nasional}',
                        style: theme.titleLarge.override(
                            font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600),
                            color: theme.primaryText,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.0)),
                  ],
                ),
              ),
            ],
          ),
          if (summary.entitas.isNotEmpty) ...[
            SizedBox(height: 8.0),
            for (final entitas in summary.entitas) ...[
              Divider(height: 1.0, thickness: 1.0, color: theme.alternate),
              row(entitas['nama_entitas']?.toString() ?? '-',
                  (entitas['total'] as num?)?.toInt() ?? 0),
            ],
          ] else
            SizedBox(height: 10.0),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: FlutterFlowTheme.of(context).titleSmall.override(
          font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          color: FlutterFlowTheme.of(context).primaryText,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.0));

  Widget _quickActions() {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Aksi Cepat'),
        SizedBox(height: 12.0),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ActionCardWidget(
                  onTap: () async {
                    await context.pushNamed(QuickReportWidget.routeName);
                    if (mounted) _load();
                  },
                  icon: LucideIcons.squarePlus,
                  iconColor: theme.primary,
                  iconBackground: theme.accent1,
                  title: 'Laporan Baru',
                ),
              ),
              Expanded(
                child: ActionCardWidget(
                  onTap: () => _openTahapList('investigasi'),
                  icon: LucideIcons.clipboardPen,
                  iconColor: theme.secondary,
                  iconBackground: theme.accent2,
                  title: tahapPendingLabels['investigasi']!,
                  count: _tahapCounts['investigasi'],
                ),
              ),
              Expanded(
                child: ActionCardWidget(
                  onTap: () => _openTahapList('verifikasi_dokter'),
                  icon: LucideIcons.stethoscope,
                  iconColor: theme.info,
                  iconBackground: theme.accent3,
                  title: tahapPendingLabels['verifikasi_dokter']!,
                  count: _tahapCounts['verifikasi_dokter'],
                ),
              ),
            ].divide(SizedBox(width: 12.0)),
          ),
        ),
      ],
    );
  }

  Widget _recentReportsSection(List<ReportListItem> items) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Laporan Terbaru')),
            TextButton(
              onPressed: () => context.goNamed(ReportHistoryWidget.routeName),
              style: TextButton.styleFrom(
                foregroundColor: theme.primary,
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                minimumSize: Size(0.0, 36.0),
              ),
              child: Text('Lihat semua',
                  style: theme.labelLarge
                      .override(color: theme.primary, letterSpacing: 0.0)),
            ),
          ],
        ),
        SizedBox(height: 8.0),
        if (items.isEmpty)
          Container(
            padding: EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.history,
                    color: theme.secondaryText, size: 36.0),
                SizedBox(height: 12.0),
                Text('Belum ada laporan',
                    style: theme.bodyMedium.override(
                        color: theme.secondaryText, letterSpacing: 0.0)),
              ],
            ),
          )
        else
          for (final (index, item) in items.indexed) ...[
            if (index > 0) SizedBox(height: 12.0),
            ReportCardWidget(
              key: Key('recent_${index}_${item.clientId ?? item.serverId}'),
              icon:
                  Icon(LucideIcons.pawPrint, color: theme.primary, size: 22.0),
              species: item.species,
              status: item.badge,
              syncStatus: item.syncStatus,
              date: item.date,
              reportCode: item.shortId,
              onTap: () async {
                await context.pushNamed(
                  FullReportWidget.routeName,
                  queryParameters: {
                    if (item.clientId != null)
                      'clientId':
                          serializeParam(item.clientId, ParamType.String),
                    if (item.clientId == null)
                      'reportId':
                          serializeParam(item.serverId, ParamType.String),
                  }.withoutNulls,
                );
                if (mounted) _load();
              },
            ),
          ],
      ],
    );
  }
}
