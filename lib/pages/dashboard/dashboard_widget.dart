import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/action_card/action_card_widget.dart';
import '/components/button/button_widget.dart';
import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/report_item/report_item_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/network/api_client.dart';
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
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardModel());
    _load();
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
      } on ApiNetworkException {
        _serverReports = [];
      }
      _summary = await DashboardRepository().fetchRingkasan(token: token);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  /// Queued reports only — drafts and legacy rows are never sent.
  List<GetAllLocalReportsRow> get _pendingLocal => _localReports
      .where((r) => r.syncStatus == 'pending' || r.syncStatus == 'failed')
      .toList();

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    await SyncRepository().runSyncQueue();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    await _load();
  }

  List<ReportListItem> get _recentItems =>
      ReportListItem.merge(_localReports, _serverReports).take(5).toList();

  (Color, Color) _statusColors(String status) {
    final theme = FlutterFlowTheme.of(context);
    switch (status.toLowerCase()) {
      case 'synced':
        return (theme.accent1, theme.success);
      case 'pending':
        return (theme.accent2, theme.warning);
      case 'draft':
        return (theme.accent3, theme.info);
      default:
        return (theme.accent4, theme.error);
    }
  }

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
                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
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
                    FlutterFlowIconButton(
                      borderRadius: 8.0,
                      buttonSize: 44.0,
                      fillColor: Colors.transparent,
                      icon: Icon(LucideIcons.circleUserRound,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 28.0),
                      onPressed: () =>
                          context.goNamed(UserProfileSettingsWidget.routeName),
                    ),
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
                  content: 'Sync Now',
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
    Widget row(String label, int total, {bool bold = false}) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: bold
                        ? theme.bodyMedium.override(fontWeight: FontWeight.bold)
                        : theme.bodyMedium),
              ),
              Text('$total laporan',
                  style: theme.bodyMedium.override(fontWeight: FontWeight.bold)),
            ],
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.alternate),
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  color: theme.accent3,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                alignment: Alignment.center,
                child: Icon(LucideIcons.barChart3, color: theme.info, size: 22.0),
              ),
              SizedBox(width: 16.0),
              Text('Ringkasan Laporan',
                  style: theme.titleMedium.override(
                      font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12.0),
          row('Nasional', summary.nasional, bold: true),
          for (final entitas in summary.entitas)
            row(entitas['nama_entitas']?.toString() ?? '-',
                (entitas['total'] as num?)?.toInt() ?? 0),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                fontWeight: FontWeight.bold)),
        SizedBox(height: 16.0),
        wrapWithModel(
          model: _model.actionCardModel1,
          updateCallback: () => safeSetState(() {}),
          child: ActionCardWidget(
            onTap: () => context.pushNamed(QuickReportWidget.routeName),
            tone: FlutterFlowTheme.of(context).primary,
            icon: Icon(LucideIcons.clipboardList,
                color: FlutterFlowTheme.of(context).primaryText, size: 24.0),
            title: 'Laporan Baru',
          ),
        ),
      ],
    );
  }

  Widget _recentReportsSection(List<ReportListItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Reports',
                style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    fontWeight: FontWeight.bold)),
            InkWell(
              onTap: () => context.goNamed(ReportHistoryWidget.routeName),
              child: wrapWithModel(
                model: _model.buttonModel2,
                updateCallback: () => safeSetState(() {}),
                child: ButtonWidget(
                  content: 'View All',
                  variant: 'ghost',
                  size: 'small',
                  fullWidth: false,
                  loading: false,
                  disabled: false,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.0),
        if (items.isEmpty)
          Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(LucideIcons.history,
                    color: FlutterFlowTheme.of(context).accent3, size: 48.0),
                SizedBox(height: 16.0),
                Text('No recent reports',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                        color: FlutterFlowTheme.of(context).secondaryText)),
              ],
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(height: 16.0),
            itemBuilder: (context, index) {
              final item = items[index];
              final (bg, fg) = _statusColors(item.syncStatus);
              return ReportItemWidget(
                key: Key('recent_${index}_${item.clientId ?? item.serverId}'),
                onTap: () => context.pushNamed(
                  FullReportWidget.routeName,
                  queryParameters: {
                    if (item.clientId != null)
                      'clientId': serializeParam(item.clientId, ParamType.String),
                    if (item.clientId == null)
                      'reportId': serializeParam(item.serverId, ParamType.String),
                  }.withoutNulls,
                ),
                species: item.species,
                idCode: item.shortId,
                date: item.date,
                statusBg: bg,
                statusLabel: item.badge,
                statusText: fg,
              );
            },
          ),
      ],
    );
  }
}

