import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../data/repositories/report_repository.dart';

class ReportInvestigationWidget extends StatefulWidget {
  const ReportInvestigationWidget({super.key, this.reportId});

  final String? reportId;

  static String routeName = 'ReportInvestigation';
  static String routePath = '/reportInvestigation';

  @override
  State<ReportInvestigationWidget> createState() =>
      _ReportInvestigationWidgetState();
}

class _ReportInvestigationWidgetState extends State<ReportInvestigationWidget> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _report;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _inspectionMethod;
  String? _evidence;
  String? _followUpCarriedOut;
  String? _additionalInformation;
  String? _dataInvestigation;

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
    final report =
        await ReportRepository().fetchOne(id: widget!.reportId, token: token);

    if (!mounted) return;
    setState(() {
      _report = report;
      if (report != null && report['investigation'] is Map) {
        final i = Map<String, dynamic>.from(report['investigation']);
        _dateFrom =
            DateTime.tryParse(i['investigation_date_from']?.toString() ?? '');
        _dateTo =
            DateTime.tryParse(i['investigation_date_to']?.toString() ?? '');
        _inspectionMethod = i['inspection_method']?.toString();
        _evidence = _joinList(i['evidence']);
        _followUpCarriedOut = i['follow_up_carried_out']?.toString();
        _additionalInformation = i['additional_information']?.toString();
        _dataInvestigation = _joinList(i['data_investigation']);
      }
      _isLoading = false;
      if (report == null) _error = 'Gagal memuat data laporan.';
    });
  }

  String? _joinList(dynamic v) => v is List ? v.join(', ') : v?.toString();
  List<String> _splitList(String? v) => (v ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
  }

  Future<void> _save() async {
    final token = FFAppState().accessToken;
    if (token == null || _report == null) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final payload = ReportRepository().mergeSection(_report!, 'investigation', {
      'investigation_date_from':
          (_dateFrom ?? now).toIso8601String().split('T').first,
      'investigation_date_to':
          (_dateTo ?? now).toIso8601String().split('T').first,
      'inspection_method': _inspectionMethod ?? '',
      'evidence': _splitList(_evidence),
      'follow_up_carried_out': _followUpCarriedOut ?? '',
      'additional_information': _additionalInformation ?? '',
      'data_investigation': _splitList(_dataInvestigation),
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
      setState(() => _error = result.message ?? 'Gagal menyimpan investigasi.');
      return;
    }
    showSnackbar(context, 'Investigasi tersimpan.');
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
                    'Investigasi Lanjutan',
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
                                  child: _dateField(
                                      label: 'Tanggal Mulai',
                                      date: _dateFrom,
                                      onTap: () => _pickDate(isFrom: true)),
                                ),
                                SizedBox(width: 12.0),
                                Expanded(
                                  child: _dateField(
                                      label: 'Tanggal Selesai',
                                      date: _dateTo,
                                      onTap: () => _pickDate(isFrom: false)),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Metode Pemeriksaan',
                              hint: 'mis. Nekropsi lapangan',
                              value: _inspectionMethod ?? '',
                              onChanged: (v) => _inspectionMethod = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Bukti (pisahkan dengan koma)',
                              hint: 'mis. Sampel jaringan, foto lokasi',
                              value: _evidence ?? '',
                              onChanged: (v) => _evidence = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Tindak Lanjut yang Dilakukan',
                              hint: 'Ringkasan tindak lanjut',
                              value: _followUpCarriedOut ?? '',
                              onChanged: (v) => _followUpCarriedOut = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Informasi Tambahan',
                              hint: 'Catatan tambahan',
                              value: _additionalInformation ?? '',
                              onChanged: (v) => _additionalInformation = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Data Investigasi (pisahkan dengan koma)',
                              hint: 'mis. Data cuaca, data populasi',
                              value: _dataInvestigation ?? '',
                              onChanged: (v) => _dataInvestigation = v,
                              variant: 'outlined',
                            ),
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
                      : Text('Simpan Investigasi',
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

  Widget _dateField(
      {required String label,
      required DateTime? date,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide:
                BorderSide(color: FlutterFlowTheme.of(context).alternate),
          ),
        ),
        child:
            Text((date ?? DateTime.now()).toIso8601String().split('T').first),
      ),
    );
  }
}
