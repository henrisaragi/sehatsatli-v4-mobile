import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/community_report_repository.dart';

/// Officer-facing view of public "Lapor Cepat" tips — API_ENDPOINTS.md §4's
/// `community-reports/getAll`/`getOne`. Read-only: promoting a tip into an
/// official case (`GeneralReportSource`) happens server-side
/// (`GenerateReportCommunity()`, see design-system.md §5.2) and isn't a
/// mobile feature per tasks.md (this item is explicitly listed "opsional").
class CommunityReportListWidget extends StatefulWidget {
  const CommunityReportListWidget({super.key});

  static String routeName = 'CommunityReportList';
  static String routePath = '/communityReportList';

  @override
  State<CommunityReportListWidget> createState() =>
      _CommunityReportListWidgetState();
}

class _CommunityReportListWidgetState extends State<CommunityReportListWidget> {
  List<CommunityReportSummary> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final reports = await CommunityReportRepository()
          .fetchAll(token: FFAppState().accessToken);
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak bisa memuat data — periksa koneksi.';
      });
    }
  }

  Future<void> _openDetail(CommunityReportSummary summary) async {
    final token = FFAppState().accessToken;
    Map<String, dynamic> detail = summary.raw;
    if (token != null) {
      final fetched = await CommunityReportRepository()
          .fetchOne(id: summary.id, token: token);
      if (fetched != null) detail = fetched;
    }
    if (!mounted) return;

    final laporan = detail['laporan'];
    final reportCode =
        laporan is Map ? laporan['report_code']?.toString() : null;
    final uptName = laporan is Map && laporan['upt'] is Map
        ? laporan['upt']['name']?.toString()
        : null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(summary.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summary.reportDate.isNotEmpty) ...[
                Text(summary.reportDate,
                    style: FlutterFlowTheme.of(dialogContext)
                        .bodySmall
                        .override(
                            color: FlutterFlowTheme.of(dialogContext)
                                .secondaryText)),
                SizedBox(height: 8.0),
              ],
              Text(summary.description),
              if (summary.promoted) ...[
                SizedBox(height: 12.0),
                Text(
                  reportCode != null
                      ? 'Sudah ditindaklanjuti sebagai laporan $reportCode${uptName != null ? ' ($uptName)' : ''}'
                      : 'Sudah ditindaklanjuti oleh petugas',
                  style: FlutterFlowTheme.of(dialogContext).bodySmall.override(
                        color: FlutterFlowTheme.of(dialogContext).success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(BuildContext context, bool promoted) {
    final color = promoted
        ? FlutterFlowTheme.of(context).success
        : FlutterFlowTheme.of(context).warning;
    final bg = promoted
        ? FlutterFlowTheme.of(context).success10
        : FlutterFlowTheme.of(context).accent2;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999.0)),
      child: Text(
        promoted ? 'Diproses' : 'Menunggu',
        style: FlutterFlowTheme.of(context)
            .labelSmall
            .override(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                padding: EdgeInsetsDirectional.fromSTEB(8.0, 22.0, 20.0, 12.0),
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
                      'Laporan Masyarakat',
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
                    child: _reports.isEmpty
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
                                  _errorMessage ??
                                      'Belum ada laporan masyarakat',
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
                            padding: EdgeInsets.all(20.0),
                            itemCount: _reports.length,
                            separatorBuilder: (_, __) => SizedBox(height: 12.0),
                            itemBuilder: (context, index) {
                              final report = _reports[index];
                              return InkWell(
                                onTap: () => _openDetail(report),
                                borderRadius: BorderRadius.circular(12.0),
                                child: Container(
                                  padding: EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              report.name,
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyLarge
                                                  .override(
                                                      font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText),
                                            ),
                                          ),
                                          _statusPill(context, report.promoted),
                                        ],
                                      ),
                                      if (report.reportDate.isNotEmpty) ...[
                                        SizedBox(height: 4.0),
                                        Text(report.reportDate,
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText)),
                                      ],
                                      SizedBox(height: 8.0),
                                      Text(
                                        report.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
