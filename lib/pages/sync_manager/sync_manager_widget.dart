import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/report_card/report_card_widget.dart';
import '/components/training_mode_banner.dart';
import '/core/utils/error_bottom_sheet.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../data/models/report_list_item.dart';
import '../../data/repositories/sync_repository.dart';
import 'sync_manager_model.dart';
export 'sync_manager_model.dart';

class SyncManagerWidget extends StatefulWidget {
  const SyncManagerWidget({super.key});

  static String routeName = 'SyncManager';
  static String routePath = '/syncManager';

  @override
  State<SyncManagerWidget> createState() => _SyncManagerWidgetState();
}

class _SyncManagerWidgetState extends State<SyncManagerWidget> {
  late SyncManagerModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isSyncing = false;
  String? _retryingId;
  List<GetAllLocalReportsRow> _reports = [];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SyncManagerModel());
    _load();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    if (kIsWeb) {
      setState(() => _isLoading = false);
      return;
    }
    final rows = await SQLiteManager.instance.getAllLocalReports();
    if (!mounted) return;
    setState(() {
      _reports = rows;
      _isLoading = false;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final result = await SyncRepository().runSyncQueue();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    await _load();
    if (!mounted) return;
    final message = result.summary(draftCount: _drafts.length);
    if (result.hasProblem || _drafts.isNotEmpty) {
      showErrorBottomSheet(
        context,
        message,
        title: result.hasProblem
            ? 'Ada laporan yang belum terkirim'
            : 'Info pengiriman',
        icon: result.stop == SyncStop.none
            ? LucideIcons.info
            : LucideIcons.cloudOff,
        warning: result.rejected.isEmpty,
      );
    } else {
      showSnackbar(context, message);
    }
  }

  Future<void> _retry(String clientId) async {
    setState(() => _retryingId = clientId);
    final result = await SyncRepository().retryFailed(clientId);
    if (!mounted) return;
    setState(() => _retryingId = null);
    await _load();
    if (!mounted) return;
    final rejection = result.rejected[clientId];
    if (result.sentClientIds.contains(clientId)) {
      showSnackbar(context, 'Laporan terkirim.');
    } else if (rejection != null) {
      showErrorBottomSheet(
        context,
        '$rejection\n\nBuka laporan untuk memeriksa datanya.',
        title: 'Masih ditolak server',
      );
    } else if (result.stopMessage != null) {
      showErrorBottomSheet(context, result.stopMessage!,
          title: 'Belum terkirim', icon: LucideIcons.cloudOff, warning: true);
    }
  }

  /// Queued for sending (pending, or rejected and waiting for "Kirim ulang").
  List<GetAllLocalReportsRow> get _queued => _reports
      .where((r) => r.syncStatus == 'pending' || r.syncStatus == 'failed')
      .toList();

  /// Never sent by the queue: unfinished drafts and pre-v4 reports.
  List<GetAllLocalReportsRow> get _drafts => _reports
      .where((r) => r.syncStatus == 'draft' || r.syncStatus == 'legacy')
      .toList();

  List<GetAllLocalReportsRow> get _synced =>
      _reports.where((r) => r.syncStatus == 'synced').toList();

  Widget _card(GetAllLocalReportsRow row) {
    final theme = FlutterFlowTheme.of(context);
    final item = ReportListItem.local(row);
    final synced = row.syncStatus == 'synced';
    return Padding(
      padding: EdgeInsets.only(bottom: 12.0),
      child: ReportCardWidget(
        onTap: () => _openReport(row),
        icon: Icon(
          synced ? LucideIcons.cloudCheck : LucideIcons.pawPrint,
          color: theme.primary,
          size: 22.0,
        ),
        species: item.species,
        status: synced ? item.status : item.badge,
        syncStatus: row.syncStatus,
        date: item.date,
        reportCode: item.shortId,
        footer: _footer(row),
      ),
    );
  }

  /// Why the report isn't on the server yet and what to do about it.
  Widget? _footer(GetAllLocalReportsRow row) {
    final theme = FlutterFlowTheme.of(context);
    final error = row.lastError?.trim();
    switch (row.syncStatus) {
      case 'failed':
        final retrying = _retryingId == row.clientId;
        return _notice(
          background: theme.accent4,
          color: theme.error,
          icon: LucideIcons.circleAlert,
          text:
              '${(error == null || error.isEmpty) ? 'Ditolak server.' : error}'
              '\nKetuk laporan ini untuk memperbaiki datanya.',
          action: TextButton.icon(
            onPressed:
                (retrying || _isSyncing) ? null : () => _retry(row.clientId),
            style: TextButton.styleFrom(
              foregroundColor: theme.error,
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              minimumSize: Size(0, 36.0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: retrying
                ? SizedBox(
                    width: 14.0,
                    height: 14.0,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.0, color: theme.error),
                  )
                : Icon(LucideIcons.refreshCw, size: 14.0),
            label: Text('Kirim ulang',
                style: theme.labelMedium
                    .override(color: theme.error, fontWeight: FontWeight.w600)),
          ),
        );
      case 'pending':
        if (error == null || error.isEmpty) return null;
        return _notice(
          background: theme.accent2,
          color: theme.warning,
          icon: LucideIcons.cloudOff,
          text: error,
        );
      case 'draft':
        return _notice(
          background: theme.accent3,
          color: theme.info,
          icon: LucideIcons.info,
          text: 'Draf belum dikirim. Buka, lengkapi data investigasi, lalu '
              'tekan "Kirim Laporan".',
        );
      case 'legacy':
        return _notice(
          background: theme.alternate,
          color: theme.secondaryText,
          icon: LucideIcons.info,
          text: 'Laporan versi lama tidak bisa dikirim ke server baru. Buat '
              'ulang lewat "Laporan Baru".',
        );
      default:
        return null;
    }
  }

  Widget _notice({
    required Color background,
    required Color color,
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding:
          EdgeInsets.fromLTRB(12.0, 10.0, 12.0, action == null ? 10.0 : 4.0),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1.0),
                child: Icon(icon, color: color, size: 16.0),
              ),
              SizedBox(width: 8.0),
              Expanded(
                child:
                    Text(text, style: theme.bodySmall.override(color: color)),
              ),
            ],
          ),
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }

  Future<void> _openReport(GetAllLocalReportsRow row) async {
    final draft = row.syncStatus == 'draft';
    await context.pushNamed(
      draft ? QuickReportWidget.routeName : FullReportWidget.routeName,
      queryParameters: {
        'clientId': serializeParam(row.clientId, ParamType.String),
      }.withoutNulls,
    );
    // The opened page may have sent, retried or deleted it.
    if (mounted) _load();
  }

  Widget _summaryCard() {
    final theme = FlutterFlowTheme.of(context);
    final queued = _queued.length;
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.primary10,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Menunggu dikirim', style: theme.bodySmall),
                Text('$queued Laporan',
                    style: theme.titleMedium
                        .override(fontWeight: FontWeight.bold)),
                if (_drafts.isNotEmpty)
                  Text('+ ${_drafts.length} draf belum dikirim',
                      style:
                          theme.bodySmall.override(color: theme.secondaryText)),
              ],
            ),
          ),
          FilledButton(
            onPressed: _isSyncing ? null : _syncNow,
            style: FilledButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: theme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
            ),
            child: _isSyncing
                ? SizedBox(
                    height: 16.0,
                    width: 16.0,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.0, color: theme.onPrimary),
                  )
                : Text('Sync Sekarang',
                    style: theme.labelLarge.override(
                        color: theme.onPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(String title, List<GetAllLocalReportsRow> rows,
      {String? empty}) {
    final theme = FlutterFlowTheme.of(context);
    return [
      SizedBox(height: 24.0),
      Text('$title (${rows.length})',
          style: theme.labelMedium.override(fontWeight: FontWeight.w600)),
      SizedBox(height: 12.0),
      if (rows.isEmpty && empty != null)
        Padding(
          padding: EdgeInsets.only(bottom: 12.0),
          child: Text(empty,
              style: theme.bodySmall.override(color: theme.secondaryText)),
        )
      else
        ...rows.map(_card),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                padding: EdgeInsetsDirectional.fromSTEB(20.0, 22.0, 20.0, 20.0),
                child: Row(
                  children: [
                    Text(
                      'Sync Manager',
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            font: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold),
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontWeight: FontWeight.bold,
                          ),
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
                    child: ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(20.0),
                      children: [
                        _summaryCard(),
                        ..._section('Antrean kirim', _queued,
                            empty: 'Tidak ada laporan yang menunggu dikirim.'),
                        if (_drafts.isNotEmpty) ..._section('Draf', _drafts),
                        ..._section('Baru tersinkron', _synced,
                            empty: 'Belum ada yang tersinkron.'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNavWidget(currentTab: MainTab.sinkron),
    );
  }
}
