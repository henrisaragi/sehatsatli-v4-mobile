import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../core/utils/option_list.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/report_repository.dart';

class ReportVerificationWidget extends StatefulWidget {
  const ReportVerificationWidget({super.key, this.reportId});

  final String? reportId;

  static String routeName = 'ReportVerification';
  static String routePath = '/reportVerification';

  @override
  State<ReportVerificationWidget> createState() =>
      _ReportVerificationWidgetState();
}

class _ReportVerificationWidgetState extends State<ReportVerificationWidget> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _report;

  List<Map<String, dynamic>> _diseases = [];
  List<Map<String, dynamic>> _doctors = [];

  DateTime? _verifiedDate = DateTime.now();
  bool _verified = false;
  String? _verificationText;
  dynamic _temporaryDiseaseId;
  String? _sampling;
  String? _action;
  String? _doctorInformation;
  List<dynamic> _involvedDoctors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = FFAppState().accessToken;
    if (token == null || widget!.reportId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Laporan tidak ditemukan.';
      });
      return;
    }
    final diseases = await MasterRepository().getCachedDiseases();
    final doctors = await MasterRepository().getCachedDokter();
    final report =
        await ReportRepository().fetchOne(id: widget!.reportId, token: token);

    if (!mounted) return;
    setState(() {
      _diseases = extractOptionList(diseases, ['diseases', 'data']);
      _doctors = extractOptionList(doctors, ['dokter', 'data']);
      _report = report;
      if (report != null && report['verification'] is Map) {
        final v = Map<String, dynamic>.from(report['verification']);
        _verified = v['verified'] == true;
        _verificationText = v['verification']?.toString();
        _temporaryDiseaseId = v['temporary_disease_id'];
        _sampling = v['sampling']?.toString();
        _action = v['action']?.toString();
        _doctorInformation = v['doctor_information']?.toString();
        _involvedDoctors = (v['involved_doctors'] as List?) ?? [];
      }
      _isLoading = false;
      if (report == null) _error = 'Gagal memuat data laporan.';
    });
  }

  Future<void> _save() async {
    final token = FFAppState().accessToken;
    if (token == null || _report == null) return;
    setState(() => _isSaving = true);

    final payload = ReportRepository().mergeSection(_report!, 'verification', {
      'verified_date':
          (_verifiedDate ?? DateTime.now()).toIso8601String().split('T').first,
      'verified': _verified,
      'verification': _verificationText ?? '',
      'temporary_disease_id': _temporaryDiseaseId,
      'sampling': _sampling ?? '',
      'action': _action ?? '',
      'doctor_information': _doctorInformation ?? '',
      'involved_doctors': _involvedDoctors,
    });

    final clientId = _report!['client_id']?.toString();
    if (clientId == null) {
      setState(() {
        _isSaving = false;
        _error = 'client_id tidak ditemukan pada laporan ini.';
      });
      return;
    }

    final result = await ReportRepository()
        .submit(clientId: clientId, payload: payload, token: token);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.status == ReportSubmitStatus.failed) {
      setState(() => _error = result.message ?? 'Gagal menyimpan verifikasi.');
      return;
    }
    showSnackbar(context, 'Verifikasi tersimpan.');
    context.pop();
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
                    'Verifikasi Dokter',
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
                              children: [
                                Expanded(
                                  child: Text('Sudah diverifikasi?',
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium),
                                ),
                                Switch(
                                  value: _verified,
                                  onChanged: (v) =>
                                      setState(() => _verified = v),
                                  activeColor:
                                      FlutterFlowTheme.of(context).primary,
                                ),
                              ],
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Catatan Verifikasi',
                              hint: 'Hasil pemeriksaan',
                              value: _verificationText ?? '',
                              onChanged: (v) => _verificationText = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            _dropdown(
                              label: 'Diagnosis Sementara',
                              value: _temporaryDiseaseId,
                              options: _diseases,
                              onChanged: (v) =>
                                  setState(() => _temporaryDiseaseId = v),
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Sampling',
                              hint: 'Sampel yang diambil',
                              value: _sampling ?? '',
                              onChanged: (v) => _sampling = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Tindakan',
                              hint: 'Tindakan yang dilakukan',
                              value: _action ?? '',
                              onChanged: (v) => _action = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Informasi Dokter',
                              hint: 'Catatan dokter pemeriksa',
                              value: _doctorInformation ?? '',
                              onChanged: (v) => _doctorInformation = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            _doctorChips(),
                            if (_error != null) ...[
                              SizedBox(height: 16.0),
                              Text(_error!,
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                          color: FlutterFlowTheme.of(context)
                                              .error)),
                            ],
                          ],
                        ),
                      ),
          ),
          if (_report != null)
            Padding(
              padding: EdgeInsets.all(16.0),
              child: InkWell(
                onTap: _isSaving ? null : _save,
                child: Container(
                  height: 48.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FlutterFlowTheme.of(context).onPrimary),
                        )
                      : Text('Simpan Verifikasi',
                          style: FlutterFlowTheme.of(context)
                              .labelLarge
                              .override(
                                  color: FlutterFlowTheme.of(context).onPrimary,
                                  fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required dynamic value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<dynamic> onChanged,
  }) {
    final validValue = options.any((o) => optionId(o) == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                color: FlutterFlowTheme.of(context).primaryText)),
        SizedBox(height: 6.0),
        DropdownButtonFormField<dynamic>(
          value: validValue,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: FlutterFlowTheme.of(context).secondaryBackground,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide:
                  BorderSide(color: FlutterFlowTheme.of(context).alternate),
            ),
            hintText: options.isEmpty ? 'Belum ada data cache' : 'Pilih $label',
          ),
          items: options
              .map((opt) => DropdownMenuItem(
                  value: optionId(opt), child: Text(optionLabel(opt))))
              .toList(),
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ],
    );
  }

  Widget _doctorChips() {
    if (_doctors.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dokter Terlibat',
            style: FlutterFlowTheme.of(context).labelMedium.override(
                font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                color: FlutterFlowTheme.of(context).primaryText)),
        SizedBox(height: 6.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: _doctors.map((doc) {
            final id = optionId(doc);
            final selected = _involvedDoctors.contains(id);
            return FilterChip(
              label: Text(optionLabel(doc)),
              selected: selected,
              onSelected: (v) => setState(() {
                if (v) {
                  _involvedDoctors.add(id);
                } else {
                  _involvedDoctors.remove(id);
                }
              }),
              selectedColor: FlutterFlowTheme.of(context).primary.withAlpha(38),
              checkmarkColor: FlutterFlowTheme.of(context).primary,
            );
          }).toList(),
        ),
      ],
    );
  }
}
