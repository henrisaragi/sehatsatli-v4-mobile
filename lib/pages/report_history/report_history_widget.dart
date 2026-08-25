import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/report_card/report_card_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/network/api_client.dart';
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
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _showTraining = false;

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
    if (!_hasMore || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadLocalReports() async {
    if (kIsWeb) return;
    try {
      // Load every local row, including already-`synced` ones — this table
      // is the only offline-first fallback source we have (there's no
      // separate read-through cache of server-fetched reports), so when the
      // server fetch below fails we still need previously-synced reports to
      // show up instead of an empty list. Duplicates against a successful
      // server fetch are filtered out in `_combinedItems` instead of here.
      final rows = await SQLiteManager.instance.getAllLocalReports();
      if (!mounted) return;
      setState(() {
        _localReports = rows;
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
        training: _showTraining,
        page: page,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        if (result.errorMessage != null) {
          // Deliberately not surfacing the raw backend message here (e.g. a
          // generic Laravel "Server Error" string) — it reads like the app
          // itself is broken. The local fallback in `_combinedItems` below
          // still renders whatever's cached; this is only seen when that's
          // also empty.
          _errorMessage =
              'Tidak bisa memuat laporan dari server. Menampilkan data lokal yang tersimpan.';
        } else {
          _serverReports.addAll(result.reports);
          _hasMore = result.hasMore;
          _page = page;
        }
      });
    } on ApiNetworkException {
      if (mounted) {
        setState(() => _errorMessage =
            'Tidak bisa memuat data online — menampilkan draf lokal saja.');
      }
    }
  }

  Future<void> _onRefresh() async {
    final token = FFAppState().accessToken;
    if (token != null) {
      // Satisfies the remaining Fase 2 "manual pull-to-refresh" item —
      // refreshes the cached master/location data alongside the report list.
      unawaited(MasterRepository().refreshAll(token: token, force: true));
    }
    await _loadFirstPage();
  }

  List<_HistoryItem> get _combinedItems {
    final query = FFAppState().historySearchQuery.trim().toLowerCase();
    final filter = FFAppState().historyFilter;

    // A local row that's already `synced` and also present in the server
    // fetch would otherwise show up twice (once with the minimal local
    // snapshot, once with the richer server copy) — drop the local copy
    // whenever the server fetch actually returned that report. Rows that
    // aren't in the server result (offline, fetch failed, or just not synced
    // yet) still show from local data.
    final serverIds = _serverReports.map((r) => _asInt(r['id'])).whereType<int>().toSet();
    final local = _localReports
        .where((r) => r.serverId == null || !serverIds.contains(r.serverId))
        .map((r) => _HistoryItem.local(r))
        .toList();
    final server = _serverReports.map((r) => _HistoryItem.server(r)).toList();
    final all = [...local, ...server];

    return all.where((item) {
      if (query.isNotEmpty && !item.species.toLowerCase().contains(query)) {
        return false;
      }
      if (filter == 'All') return true;
      return item.status.toLowerCase() == filter.toLowerCase();
    }).toList();
  }

  Widget _filterChip(String label) {
    final active = FFAppState().historyFilter == label;
    return InkWell(
      onTap: () => setState(() => FFAppState().historyFilter = label),
      borderRadius: BorderRadius.circular(999.0),
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
        decoration: BoxDecoration(
          color: active
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(999.0),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Text(
          label,
          style: FlutterFlowTheme.of(context).labelMedium.override(
                color: active
                    ? FlutterFlowTheme.of(context).onPrimary
                    : FlutterFlowTheme.of(context).primaryText,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _combinedItems;

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
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                border: Border(
                    bottom: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
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
                                color: FlutterFlowTheme.of(context).primaryText,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        FlutterFlowIconButton(
                          borderRadius: 8.0,
                          buttonSize: 40.0,
                          fillColor: _showTraining
                              ? FlutterFlowTheme.of(context).accent2
                              : Colors.transparent,
                          icon: Icon(
                            LucideIcons.graduationCap,
                            color: _showTraining
                                ? FlutterFlowTheme.of(context).warning
                                : FlutterFlowTheme.of(context).primaryText,
                            size: 22.0,
                          ),
                          onPressed: () {
                            setState(() => _showTraining = !_showTraining);
                            _loadFirstPage();
                          },
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
                    SizedBox(height: 12.0),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('All'),
                          SizedBox(width: 8.0),
                          _filterChip('Draft'),
                          SizedBox(width: 8.0),
                          _filterChip('Pending'),
                          SizedBox(width: 8.0),
                          _filterChip('Synced'),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
            TrainingModeBanner(),
            Expanded(
              child: _isLoadingFirstPage
                  ? Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: items.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: 96.0),
                                Icon(LucideIcons.package,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 48.0),
                                SizedBox(height: 12.0),
                                Center(
                                  child: Text(
                                    _errorMessage ?? 'Belum ada laporan',
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
                              padding: EdgeInsets.all(20.0),
                              itemCount: items.length + (_hasMore ? 1 : 0),
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
                                return ReportCardWidget(
                                  icon: Icon(LucideIcons.pawPrint,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 24.0),
                                  species: item.species,
                                  status: item.status,
                                  date: item.date,
                                  reportCode: item.reportCode,
                                  onTap: () {
                                    if (item.serverId == null) {
                                      // Not synced yet (draft/pending/failed)
                                      // — editable via the same Full Report
                                      // page instead of a dead-end message.
                                      context.pushNamed(
                                        FullReportWidget.routeName,
                                        queryParameters: {
                                          'clientId': serializeParam(
                                              item.clientId,
                                              ParamType.String),
                                        }.withoutNulls,
                                      );
                                      return;
                                    }
                                    context.pushNamed(
                                      FullReportWidget.routeName,
                                      queryParameters: {
                                        'reportId': serializeParam(
                                            item.serverId.toString(),
                                            ParamType.String),
                                      }.withoutNulls,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: MainBottomNavWidget(currentTab: MainTab.laporan),
      ),
    );
  }
}

/// `local_reports.updated_at`/`created_at` are stored as full ISO-8601
/// timestamps with microsecond precision — see the identical helper in
/// `dashboard_widget.dart` for why this is needed (RenderFlex overflow).
String _formatLocalDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  return parsed != null ? dateTimeFormat('yyyy-MM-dd', parsed) : raw;
}

int? _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : null);

class _HistoryItem {
  _HistoryItem({
    required this.species,
    required this.status,
    required this.date,
    required this.reportCode,
    this.serverId,
    this.clientId,
  });

  factory _HistoryItem.local(GetAllLocalReportsRow row) {
    final status = row.syncStatus.isEmpty
        ? 'Draft'
        : '${row.syncStatus[0].toUpperCase()}${row.syncStatus.substring(1)}';
    return _HistoryItem(
      species: 'Draf laporan',
      status: status,
      date: _formatLocalDate(row.updatedAt ?? row.createdAt),
      reportCode: row.reportCode ?? row.clientId,
      serverId: row.serverId,
      clientId: row.clientId,
    );
  }

  // Matches the web list at `laporan-umum` (columns: Kode Laporan, Nama
  // Spesies, Tanggal Laporan) — report code instead of location.
  factory _HistoryItem.server(Map<String, dynamic> report) {
    final species = report['species'];
    final speciesName = species is Map && species['species_name'] != null
        ? species['species_name'].toString()
        : (report['species_name'] ?? 'Spesies tidak diketahui').toString();
    final isProtected = species is Map && species['protected'] == true;
    return _HistoryItem(
      species: speciesName,
      status: isProtected ? 'Prioritas' : 'Synced',
      date: (report['report_date'] ?? '').toString(),
      reportCode: (report['report_code'] ?? '-').toString(),
      serverId: report['id'],
    );
  }

  final String species;
  final String status;
  final String date;
  final String reportCode;
  final dynamic serverId;
  final String? clientId;
}
