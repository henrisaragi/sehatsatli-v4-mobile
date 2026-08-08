import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/components/info_row/info_row_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../core/utils/option_list.dart';
import '../../data/repositories/report_repository.dart';
import 'report_detail_view_model.dart';
export 'report_detail_view_model.dart';

class ReportDetailViewWidget extends StatefulWidget {
  const ReportDetailViewWidget({
    super.key,
    this.reportId,
  });

  final String? reportId;

  static String routeName = 'ReportDetailView';
  static String routePath = '/reportDetailView';

  @override
  State<ReportDetailViewWidget> createState() => _ReportDetailViewWidgetState();
}

class _ReportDetailViewWidgetState extends State<ReportDetailViewWidget> {
  late ReportDetailViewModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ReportDetailViewModel());
    _load();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final token = FFAppState().accessToken;
    if (token == null || widget!.reportId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Laporan tidak ditemukan.';
      });
      return;
    }
    final report =
        await ReportRepository().fetchOne(id: widget!.reportId, token: token);
    if (!mounted) return;
    setState(() {
      _report = report;
      _isLoading = false;
      if (report == null) _error = 'Gagal memuat data laporan.';
    });
  }

  Future<void> _delete() async {
    final token = FFAppState().accessToken;
    final clientId = _report?['client_id']?.toString();
    if (token == null || clientId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Laporan?'),
        content: Text(
            'Laporan ini akan dihapus dari server. Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Batal')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final success = await ReportRepository().delete(clientId, token: token);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (success) {
      showSnackbar(context, 'Laporan dihapus.');
      context.pop();
    } else {
      showSnackbar(context, 'Gagal menghapus laporan.');
    }
  }

  Map<String, dynamic>? _section(String key) {
    final value = _report?[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  List<Map<String, dynamic>> _mediaItems() {
    final raw = _report?['media'] ?? _report?['photos'] ?? _report?['files'];
    return extractOptionList(raw, ['media', 'photos', 'files', 'data']);
  }

  String? _mediaUrl(Map<String, dynamic> item) {
    final v =
        item['url'] ?? item['path'] ?? item['file_url'] ?? item['media_url'];
    return v?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final reporter = _section('reporter');
    final locations = _section('locations') ?? _section('location');
    final species = _section('species');
    final diagnoses = _section('diagnoses');
    final verification = _section('verification');
    final lab = _section('lab');
    final investigation = _section('investigation');
    final media = _mediaItems();

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      FlutterFlowIconButton(
                        borderRadius: 8.0,
                        buttonSize: 40.0,
                        icon: Icon(Icons.arrow_back_rounded,
                            color: FlutterFlowTheme.of(context).primaryText),
                        onPressed: () => context.pop(),
                      ),
                      Text(
                        'Detail Laporan',
                        style: FlutterFlowTheme.of(context).titleLarge.override(
                              font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold),
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  FlutterFlowIconButton(
                    borderRadius: 8.0,
                    buttonSize: 40.0,
                    icon: Icon(Icons.refresh_rounded,
                        color: FlutterFlowTheme.of(context).primary),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
          ),
          TrainingModeBanner(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _report == null
                    ? Center(
                        child: Text(_error ?? 'Gagal memuat laporan',
                            style: FlutterFlowTheme.of(context).bodyMedium))
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (species?['species_name'] ??
                                                'Spesies tidak diketahui')
                                            .toString(),
                                        style: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .override(
                                                fontWeight: FontWeight.bold),
                                      ),
                                      if (species?['species_latin_name'] !=
                                          null)
                                        Text(
                                          species!['species_latin_name']
                                              .toString(),
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                  fontStyle: FontStyle.italic,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText),
                                        ),
                                    ],
                                  ),
                                ),
                                if (species?['protected'] == true)
                                  Container(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 10.0, 4.0),
                                    decoration: BoxDecoration(
                                      color:
                                          FlutterFlowTheme.of(context).accent4,
                                      borderRadius:
                                          BorderRadius.circular(999.0),
                                    ),
                                    child: Text(
                                      'Dilindungi',
                                      style: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .override(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .error,
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              (_report!['report_code'] ??
                                      _report!['client_id'] ??
                                      '-')
                                  .toString(),
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText),
                            ),
                            Divider(height: 32.0),
                            _sectionCard(
                              title: 'Pelapor',
                              icon: Icons.person_rounded,
                              children: [
                                InfoRowWidget(
                                    icon: Icon(Icons.badge_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText),
                                    label: 'Nama',
                                    value:
                                        (reporter?['name'] ?? '-').toString()),
                                InfoRowWidget(
                                    icon: Icon(Icons.work_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText),
                                    label: 'Pekerjaan',
                                    value: (reporter?['occupation'] ?? '-')
                                        .toString()),
                                InfoRowWidget(
                                    icon: Icon(Icons.call_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText),
                                    label: 'No. HP',
                                    value:
                                        (reporter?['phone'] ?? '-').toString()),
                              ],
                            ),
                            SizedBox(height: 16.0),
                            _sectionCard(
                              title: 'Lokasi',
                              icon: Icons.location_on_rounded,
                              children: [
                                InfoRowWidget(
                                    icon: Icon(Icons.place_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText),
                                    label: 'Nama Lokasi',
                                    value: (locations?['location_name'] ?? '-')
                                        .toString()),
                                InfoRowWidget(
                                    icon: Icon(Icons.my_location_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText),
                                    label: 'Koordinat',
                                    value:
                                        '${locations?['latitude'] ?? '-'}, ${locations?['longitude'] ?? '-'}'),
                              ],
                            ),
                            SizedBox(height: 16.0),
                            _sectionCard(
                              title: 'Diagnosis Awal',
                              icon: Icons.medical_services_rounded,
                              children: [
                                InfoRowWidget(
                                    icon: Icon(Icons.pets_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText),
                                    label: 'Mati / Hidup',
                                    value:
                                        '${diagnoses?['dead'] ?? 0} / ${diagnoses?['live'] ?? 0}'),
                                InfoRowWidget(
                                    icon: Icon(Icons.notes_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText),
                                    label: 'Catatan',
                                    value: (diagnoses?['diagnosis'] ??
                                            _report!['description'] ??
                                            '-')
                                        .toString()),
                              ],
                            ),
                            SizedBox(height: 16.0),
                            Text('Foto Bukti',
                                style: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(fontWeight: FontWeight.w600)),
                            SizedBox(height: 8.0),
                            media.isEmpty
                                ? Text('Belum ada foto',
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText))
                                : SizedBox(
                                    height: 90.0,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: media.length,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(width: 8.0),
                                      itemBuilder: (context, i) {
                                        final url = _mediaUrl(media[i]);
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(9.0),
                                          child: url != null
                                              ? CachedNetworkImage(
                                                  imageUrl: url,
                                                  width: 90.0,
                                                  height: 90.0,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) =>
                                                      _photoPlaceholder(
                                                          context),
                                                )
                                              : _photoPlaceholder(context),
                                        );
                                      },
                                    ),
                                  ),
                            if (FFAppState().isDoctor) ...[
                              SizedBox(height: 24.0),
                              Text('Tahap Lanjutan (Dokter)',
                                  style: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(fontWeight: FontWeight.w600)),
                              SizedBox(height: 8.0),
                              _stage5Row(
                                  label: 'Verifikasi Dokter',
                                  filled: verification != null,
                                  onTap: () => context.pushNamed(
                                        ReportVerificationWidget.routeName,
                                        queryParameters: {
                                          'reportId': serializeParam(
                                              widget!.reportId,
                                              ParamType.String),
                                        }.withoutNulls,
                                      )),
                              _stage5Row(
                                  label: 'Hasil Lab',
                                  filled: lab != null,
                                  onTap: () => context.pushNamed(
                                        ReportLabWidget.routeName,
                                        queryParameters: {
                                          'reportId': serializeParam(
                                              widget!.reportId,
                                              ParamType.String),
                                        }.withoutNulls,
                                      )),
                              _stage5Row(
                                  label: 'Investigasi Lanjutan',
                                  filled: investigation != null,
                                  onTap: () => context.pushNamed(
                                        ReportInvestigationWidget.routeName,
                                        queryParameters: {
                                          'reportId': serializeParam(
                                              widget!.reportId,
                                              ParamType.String),
                                        }.withoutNulls,
                                      )),
                            ],
                          ],
                        ),
                      ),
          ),
          if (_report != null)
            Container(
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                border: Border(
                    top: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _isDeleting ? null : _delete,
                        child: Container(
                          height: 48.0,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: FlutterFlowTheme.of(context).error),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          alignment: Alignment.center,
                          child: _isDeleting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          FlutterFlowTheme.of(context).error))
                              : Text('Hapus',
                                  style: FlutterFlowTheme.of(context)
                                      .labelLarge
                                      .override(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(BuildContext context) => Container(
        width: 90.0,
        height: 90.0,
        color: FlutterFlowTheme.of(context).secondaryBackground,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_rounded,
            color: FlutterFlowTheme.of(context).secondaryText),
      );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  color: FlutterFlowTheme.of(context).primary, size: 18.0),
              SizedBox(width: 8.0),
              Text(title,
                  style: FlutterFlowTheme.of(context)
                      .titleSmall
                      .override(fontWeight: FontWeight.bold)),
            ],
          ),
          SizedBox(height: 12.0),
          ...children.map(
              (c) => Padding(padding: EdgeInsets.only(bottom: 10.0), child: c)),
        ],
      ),
    );
  }

  Widget _stage5Row(
      {required String label,
      required bool filled,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.0),
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: FlutterFlowTheme.of(context).alternate),
        ),
        child: Row(
          children: [
            Icon(
              filled
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: filled
                  ? FlutterFlowTheme.of(context).success
                  : FlutterFlowTheme.of(context).secondaryText,
              size: 20.0,
            ),
            SizedBox(width: 12.0),
            Expanded(
              child:
                  Text(label, style: FlutterFlowTheme.of(context).bodyMedium),
            ),
            Text(
              filled ? 'Terisi' : 'Isi sekarang',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    color: filled
                        ? FlutterFlowTheme.of(context).success
                        : FlutterFlowTheme.of(context).primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
