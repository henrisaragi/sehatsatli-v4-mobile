import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/report_card/report_card_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/network/api_client.dart';
import '../../data/models/report_list_item.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/report_repository.dart';
import 'report_history_model.dart';
export 'report_history_model.dart';

class ReportHistoryWidget extends StatefulWidget {
  const ReportHistoryWidget({super.key});

  static String routeName = 'ReportHistory';
  static String routePath = '/reportHistory';

  @override
  State<ReportHistoryWidget> createState() => _ReportHistoryWidgetState();
}

class _ReportHistoryWidgetState extends State<ReportHistoryWidget> {
  late ReportHistoryModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  List<GetAllLocalReportsRow> _localReports = [];
  final List<Map<String, dynamic>> _serverReports = [];
  bool _showUnsent = false;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ReportHistoryModel());
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _model.dispose();

    super.dispose();
  }

  void _onScroll() {
    if (_showUnsent || !_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadLocalReports() async {
    if (kIsWeb) return;
    try {
      final rows = await SQLiteManager.instance.getAllLocalReports();
      if (!mounted) return;
      setState(() {
        // Only reports that haven't reached the server; once synced they
        // show up in the server list instead.
        _localReports = rows.where((r) => r.syncStatus != 'synced').toList();
      });
    } catch (_) {
      // sqflite unavailable (e.g. web) — local drafts just won't show.
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoadingFirstPage = true;
      _errorMessage = null;
      _page = 1;
      _serverReports.clear();
      _hasMore = true;
    });
    await _loadLocalReports();
    await _fetchPage(1);
    if (mounted) setState(() => _isLoadingFirstPage = false);
  }

  Future<void> _loadNextPage() async {
    setState(() => _isLoadingMore = true);
    await _fetchPage(_page + 1);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _fetchPage(int page) async {
    final token = FFAppState().accessToken;
    if (token == null) {
      setState(
          () => _errorMessage = 'Sesi tidak ditemukan, silakan masuk kembali.');
      return;
    }
    try {
      final result = await ReportRepository().fetchReports(
        page: page,
        token: token,
        scope: ReportListScope.entitas,
      );
      if (!mounted) return;
      setState(() {
        if (result.errorMessage != null) {
          // Deliberately not surfacing the raw backend message (e.g. a
          // generic Laravel "Server Error") — it reads like the app is broken.
          _errorMessage = 'Tidak bisa memuat laporan dari server.';
          _hasMore = false;
        } else {
          _serverReports.addAll(result.reports);
          _hasMore = result.hasMore;
          _page = page;
        }
      });
    } on ApiNetworkException {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Tidak bisa memuat laporan — periksa koneksi internet.';
          _hasMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    final token = FFAppState().accessToken;
    if (token != null) {
      // Refreshes the cached master data alongside the report list.
      unawaited(MasterRepository().refreshAll(token: token, force: true));
    }
    await _loadFirstPage();
  }

  List<ReportListItem> get _visibleItems {
    final query = FFAppState().historySearchQuery.trim().toLowerCase();
    final items = _showUnsent
        ? _localReports.map(ReportListItem.local)
        : _serverReports.map(ReportListItem.server);
    return items
        .where((item) =>
            query.isEmpty || item.species.toLowerCase().contains(query))
        .toList();
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus laporan dari perangkat?'),
        content: Text(
            'Laporan ini belum ada di server. Data yang dihapus tidak bisa dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Hapus',
                  style: TextStyle(color: FlutterFlowTheme.of(context).error))),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteLocal(String clientId) async {
    // Drop it from the list first so the dismissed row isn't rebuilt.
    setState(() => _localReports.removeWhere((r) => r.clientId == clientId));
    await ReportRepository().deleteLocal(clientId);
    if (!mounted) return;
    showSnackbar(context, 'Laporan dihapus dari perangkat.');
  }

  Widget _deleteBackground() {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 24.0),
      decoration: BoxDecoration(
        color: theme.error,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.trash2, color: Colors.white, size: 22.0),
          SizedBox(height: 4.0),
          Text('Hapus',
              style: theme.labelSmall
                  .override(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool unsentTab, {int? count}) {
    final theme = FlutterFlowTheme.of(context);
    final active = _showUnsent == unsentTab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _showUnsent = unsentTab),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? theme.primary : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.labelLarge.override(
                  color: active ? theme.primary : theme.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count != null && count > 0) ...[
                SizedBox(width: 6.0),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.0, vertical: 1.0),
                  decoration: BoxDecoration(
                    color: theme.secondary,
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                  child: Text(
                    '$count',
                    style: theme.labelSmall.override(
                      color: theme.onSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final showLoadMore = !_showUnsent && _hasMore;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Laporan Kasus',
                            style: FlutterFlowTheme.of(context)
                                .headlineSmall
                                .override(
                                  font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.0),
                      TextFieldWidget(
                        label: '',
                        labelPresent: false,
                        hint: 'Cari spesies...',
                        leadingIcon: Icon(LucideIcons.search,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 20.0),
                        leadingIconPresent: true,
                        value: FFAppState().historySearchQuery,
                        onChanged: (v) =>
                            setState(() => FFAppState().historySearchQuery = v),
                        variant: 'outlined',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                border: Border(
                    bottom: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate)),
              ),
              child: Row(
                children: [
                  _tab('Laporan', false),
                  _tab('Belum Terkirim', true, count: _localReports.length),
                ],
              ),
            ),
            TrainingModeBanner(),
            Expanded(
              child: _isLoadingFirstPage && !_showUnsent
                  ? Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: items.isEmpty
                          ? ListView(
                              physics: AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: 96.0),
                                Icon(LucideIcons.package,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 48.0),
                                SizedBox(height: 12.0),
                                Center(
                                  child: Text(
                                    _showUnsent
                                        ? 'Semua laporan sudah terkirim'
                                        : (_errorMessage ??
                                            'Belum ada laporan'),
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              physics: AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(20.0),
                              itemCount: items.length + (showLoadMore ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 12.0),
                              itemBuilder: (context, index) {
                                if (index >= items.length) {
                                  return Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16.0),
                                    child: Center(
                                      child: _isLoadingMore
                                          ? CircularProgressIndicator()
                                          : SizedBox.shrink(),
                                    ),
                                  );
                                }
                                final item = items[index];
                                final card = ReportCardWidget(
                                  icon: Icon(LucideIcons.pawPrint,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 22.0),
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
                                          'clientId': serializeParam(
                                              item.clientId, ParamType.String),
                                        if (item.clientId == null)
                                          'reportId': serializeParam(
                                              item.serverId, ParamType.String),
                                      }.withoutNulls,
                                    );
                                    // The detail page can send or delete it.
                                    if (mounted) _loadFirstPage();
                                  },
                                );
                                if (!item.isDeletable) return card;
                                return Dismissible(
                                  key: ValueKey('local_${item.clientId}'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) => _confirmDelete(),
                                  onDismissed: (_) =>
                                      _deleteLocal(item.clientId!),
                                  background: _deleteBackground(),
                                  child: card,
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: MainBottomNavWidget(
          currentTab: MainTab.laporan,
          onQuickReportClosed: _loadFirstPage,
        ),
      ),
    );
  }
}
