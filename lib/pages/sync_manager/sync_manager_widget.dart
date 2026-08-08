import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/components/sync_item/sync_item_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../backend/sqlite/sqlite_manager.dart';
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
    await SyncRepository().runSyncQueue();
    if (!mounted) return;
    setState(() => _isSyncing = false);
    await _load();
  }

  List<GetAllLocalReportsRow> get _pending =>
      _reports.where((r) => r.syncStatus != 'synced').toList();
  List<GetAllLocalReportsRow> get _synced =>
      _reports.where((r) => r.syncStatus == 'synced').toList();

  Color _statusBg(String status) {
    switch (status) {
      case 'failed':
        return FlutterFlowTheme.of(context).accent4;
      case 'draft':
        return FlutterFlowTheme.of(context).accent3;
      default:
        return FlutterFlowTheme.of(context).accent2;
    }
  }

  Color _statusText(String status) {
    switch (status) {
      case 'failed':
        return FlutterFlowTheme.of(context).error;
      case 'draft':
        return FlutterFlowTheme.of(context).info;
      default:
        return FlutterFlowTheme.of(context).warning;
    }
  }

  void _openReport(GetAllLocalReportsRow row) {
    if (row.serverId == null) {
      // Not synced yet (draft/pending/failed) — editable via the same
      // Full Report page instead of a dead-end message.
      context.pushNamed(
        FullReportWidget.routeName,
        queryParameters: {
          'clientId': serializeParam(row.clientId, ParamType.String),
        }.withoutNulls,
      );
      return;
    }
    context.pushNamed(
      FullReportWidget.routeName,
      queryParameters: {
        'reportId': serializeParam(row.serverId.toString(), ParamType.String),
      }.withoutNulls,
    );
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
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(8.0, 30.0, 20.0, 20.0),
              child: Row(
                children: [
                  FlutterFlowIconButton(
                    borderRadius: 8.0,
                    buttonSize: 40.0,
                    icon: Icon(Icons.arrow_back_rounded,
                        color: FlutterFlowTheme.of(context).primaryText),
                    onPressed: () => context.pop(),
                  ),
                  Text(
                    'Sync Manager',
                    style: FlutterFlowTheme.of(context).titleLarge.override(
                          font:
                              GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          color: FlutterFlowTheme.of(context).primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          TrainingModeBanner(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.all(20.0),
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primary10,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Menunggu Sinkron',
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall),
                                  Text('${_pending.length} Laporan',
                                      style: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .override(
                                              fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: (_isSyncing || _pending.isEmpty)
                                  ? null
                                  : _syncNow,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10.0),
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: _isSyncing
                                    ? SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: FlutterFlowTheme.of(context)
                                                .onPrimary),
                                      )
                                    : Text('Sync Sekarang',
                                        style: FlutterFlowTheme.of(context)
                                            .labelLarge
                                            .override(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .onPrimary,
                                                fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.0),
                      Text('Antrean (${_pending.length})',
                          style: FlutterFlowTheme.of(context)
                              .labelMedium
                              .override(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8.0),
                      if (_pending.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Tidak ada laporan yang menunggu.',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText)),
                        )
                      else
                        ..._pending.map((row) => Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: InkWell(
                                onTap: () => _openReport(row),
                                child: SyncItemWidget(
                                  title: row.reportCode ?? row.clientId,
                                  date: row.updatedAt ?? row.createdAt,
                                  statusBg: _statusBg(row.syncStatus),
                                  status: row.syncStatus,
                                  statusText: _statusText(row.syncStatus),
                                  hasError: row.syncStatus == 'failed',
                                ),
                              ),
                            )),
                      SizedBox(height: 24.0),
                      Text('Baru Tersinkron',
                          style: FlutterFlowTheme.of(context)
                              .labelMedium
                              .override(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8.0),
                      if (_synced.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Belum ada yang tersinkron.',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText)),
                        )
                      else
                        ..._synced.map((row) => Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: InkWell(
                                onTap: () => _openReport(row),
                                child: Container(
                                  padding: EdgeInsets.all(12.0),
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .success,
                                          size: 20.0),
                                      SizedBox(width: 12.0),
                                      Expanded(
                                        child: Text(
                                            row.reportCode ?? row.clientId,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium),
                                      ),
                                      Icon(Icons.cloud_done_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .success,
                                          size: 18.0),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
