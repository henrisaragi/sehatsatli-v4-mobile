import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      final rows = await SQLiteManager.instance.getAllLocalReports();
      if (!mounted) return;
      setState(() {
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
        training: _showTraining,
        page: page,
        token: token,
      );
      if (!mounted) return;
      setState(() {
        if (result.errorMessage != null) {
          _errorMessage = result.errorMessage;
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

    final local = _localReports.map((r) => _HistoryItem.local(r)).toList();
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
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(20.0, 30.0, 20.0, 12.0),
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
                            Icons.school_rounded,
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
                      leadingIcon: Icon(Icons.search_rounded,
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
                                Icon(Icons.inventory_2_rounded,
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
                                  icon: Icon(Icons.pets_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 24.0),
                                  species: item.species,
                                  status: item.status,
                                  date: item.date,
                                  location: item.location,
                                  onTap: () {
                                    if (item.serverId == null) {
                                      // Not synced yet (draft/pending/failed)
                                      // — editable via the same wizard
                                      // instead of a dead-end message.
                                      context.pushNamed(
                                        NewGeneralReportWidget.routeName,
                                        queryParameters: {
                                          'clientId': serializeParam(
                                              item.clientId,
                                              ParamType.String),
                                        }.withoutNulls,
                                      );
                                      return;
                                    }
                                    context.pushNamed(
                                      ReportDetailViewWidget.routeName,
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

class _HistoryItem {
  _HistoryItem({
    required this.species,
    required this.status,
    required this.date,
    required this.location,
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
      date: row.updatedAt ?? row.createdAt,
      location: row.reportCode ?? row.clientId,
      serverId: row.serverId,
      clientId: row.clientId,
    );
  }

  factory _HistoryItem.server(Map<String, dynamic> report) {
    final species = report['species'];
    final speciesName = species is Map && species['species_name'] != null
        ? species['species_name'].toString()
        : (report['species_name'] ?? 'Spesies tidak diketahui').toString();
    final location = report['locations'];
    final locationName = location is Map && location['location_name'] != null
        ? location['location_name'].toString()
        : (report['location_name'] ?? '-').toString();
    final isProtected = species is Map && species['protected'] == true;
    return _HistoryItem(
      species: speciesName,
      status: isProtected ? 'Prioritas' : 'Synced',
      date: (report['report_date'] ?? '').toString(),
      location: locationName,
      serverId: report['id'],
    );
  }

  final String species;
  final String status;
  final String date;
  final String location;
  final dynamic serverId;
  final String? clientId;
}
