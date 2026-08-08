import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/community_report_repository.dart';

/// Public "Lapor Cepat" form — API_ENDPOINTS.md §4's `community-reports/save`
/// needs no login, so this page is reachable without an access token (see
/// `_kPublicRoutePaths` in nav.dart) from the login screen. Unlike the main
/// report wizard, there's no offline queue here: the endpoint (and this
/// feature) is explicitly a lightweight, online-only public tip line, not
/// part of the field-officer offline-first architecture in CLAUDE.md §5.
class CommunityReportWidget extends StatefulWidget {
  const CommunityReportWidget({super.key});

  static String routeName = 'CommunityReport';
  static String routePath = '/communityReport';

  @override
  State<CommunityReportWidget> createState() => _CommunityReportWidgetState();
}

const _indonesianMonths = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

// Spelled out manually instead of `DateFormat(..., 'id_ID')` — the intl
// locale data for 'id_ID' is never initialized anywhere in this app
// (no `initializeDateFormatting()` call), so that would throw at runtime.
String _formatDate(DateTime date) =>
    '${date.day} ${_indonesianMonths[date.month - 1]} ${date.year}';

class _CommunityReportWidgetState extends State<CommunityReportWidget> {
  final _descriptionController = TextEditingController();

  String _name = '';
  DateTime _reportDate = DateTime.now();
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _reportDate = picked);
  }

  Future<void> _submit() async {
    final name = _name.trim();
    final description = _descriptionController.text.trim();
    if (name.isEmpty || description.isEmpty) {
      setState(() => _error = 'Nama dan deskripsi wajib diisi');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await CommunityReportRepository().save(
        name: name,
        reportDate: _reportDate,
        description: description,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (!result.success) {
        setState(() => _error = result.message ?? 'Gagal mengirim laporan');
        return;
      }
      setState(() => _submitted = true);
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Tidak bisa terhubung ke server — periksa koneksi internet';
      });
    }
  }

  void _resetForm() {
    _descriptionController.clear();
    setState(() {
      _name = '';
      _reportDate = DateTime.now();
      _submitted = false;
      _error = null;
    });
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
                  bottom:
                      BorderSide(color: FlutterFlowTheme.of(context).alternate)),
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
                      'Laporan Cepat',
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: _submitted ? _successView(context) : _formView(context),
            ),
          ),
          if (!_submitted)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: InkWell(
                  onTap: _isSubmitting ? null : _submit,
                  child: Container(
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primary,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    alignment: Alignment.center,
                    child: _isSubmitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FlutterFlowTheme.of(context).onPrimary),
                          )
                        : Text('Kirim Laporan',
                            style: FlutterFlowTheme.of(context)
                                .labelLarge
                                .override(
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _formView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).accent3,
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: FlutterFlowTheme.of(context).info, size: 20.0),
              SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  'Tidak perlu akun. Laporan Anda akan ditindaklanjuti oleh petugas terkait.',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                      color: FlutterFlowTheme.of(context).primaryText),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.0),
        TextFieldWidget(
          label: 'Nama Pelapor',
          hint: 'Nama Anda',
          value: _name,
          onChanged: (v) => _name = v,
          variant: 'outlined',
        ),
        SizedBox(height: 16.0),
        Text('Tanggal Kejadian',
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: FlutterFlowTheme.of(context).primaryText,
                )),
        SizedBox(height: 6.0),
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 18.0, color: FlutterFlowTheme.of(context).primaryText),
                SizedBox(width: 12.0),
                Text(
                  _formatDate(_reportDate),
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.0),
        Text('Deskripsi Kejadian',
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: FlutterFlowTheme.of(context).primaryText,
                )),
        SizedBox(height: 6.0),
        TextFormField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Ceritakan apa yang Anda temukan/lihat...',
            hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                color: FlutterFlowTheme.of(context).secondaryText),
            filled: true,
            fillColor: FlutterFlowTheme.of(context).secondaryBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate),
            ),
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: 16.0),
          Text(_error!,
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: FlutterFlowTheme.of(context).error)),
        ],
      ],
    );
  }

  Widget _successView(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 32.0),
        Container(
          width: 88.0,
          height: 88.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).success10,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.check_rounded,
              color: FlutterFlowTheme.of(context).success, size: 48.0),
        ),
        SizedBox(height: 24.0),
        Text(
          'Laporan Terkirim',
          style: FlutterFlowTheme.of(context).titleLarge.override(
                font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                color: FlutterFlowTheme.of(context).primaryText,
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: 8.0),
        Text(
          'Terima kasih. Laporan Anda telah diterima dan akan ditindaklanjuti oleh petugas.',
          textAlign: TextAlign.center,
          style: FlutterFlowTheme.of(context)
              .bodyMedium
              .override(color: FlutterFlowTheme.of(context).secondaryText),
        ),
        SizedBox(height: 32.0),
        InkWell(
          onTap: _resetForm,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: FlutterFlowTheme.of(context).primary),
            ),
            child: Text('Kirim Laporan Lain',
                style: FlutterFlowTheme.of(context).labelLarge.override(
                    color: FlutterFlowTheme.of(context).primary,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        SizedBox(height: 12.0),
        InkWell(
          onTap: () => context.pop(),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Kembali',
                style: FlutterFlowTheme.of(context).labelLarge.override(
                    color: FlutterFlowTheme.of(context).secondaryText)),
          ),
        ),
      ],
    );
  }
}
