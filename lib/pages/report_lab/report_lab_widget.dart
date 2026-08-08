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

class ReportLabWidget extends StatefulWidget {
  const ReportLabWidget({super.key, this.reportId});

  final String? reportId;

  static String routeName = 'ReportLab';
  static String routePath = '/reportLab';

  @override
  State<ReportLabWidget> createState() => _ReportLabWidgetState();
}

class _ReportLabWidgetState extends State<ReportLabWidget> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _report;

  List<Map<String, dynamic>> _diseases = [];

  dynamic _finalDiseaseId;
  String? _finalDiagnosis;
  String? _followUp;

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
    final report =
        await ReportRepository().fetchOne(id: widget!.reportId, token: token);

    if (!mounted) return;
    setState(() {
      _diseases = extractOptionList(diseases, ['diseases', 'data']);
      _report = report;
      if (report != null && report['lab'] is Map) {
        final l = Map<String, dynamic>.from(report['lab']);
        _finalDiseaseId = l['final_disease_id'];
        _finalDiagnosis = l['final_diagnosis']?.toString();
        _followUp = l['follow_up']?.toString();
      }
      _isLoading = false;
      if (report == null) _error = 'Gagal memuat data laporan.';
    });
  }

  Future<void> _save() async {
    final token = FFAppState().accessToken;
    if (token == null || _report == null) return;
    setState(() => _isSaving = true);

    final payload = ReportRepository().mergeSection(_report!, 'lab', {
      'final_disease_id': _finalDiseaseId,
      'final_diagnosis': _finalDiagnosis ?? '',
      'follow_up': _followUp ?? '',
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
      setState(() => _error = result.message ?? 'Gagal menyimpan hasil lab.');
      return;
    }
    showSnackbar(context, 'Hasil lab tersimpan.');
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
                    'Hasil Lab',
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
                            _dropdown(
                              label: 'Diagnosis Akhir',
                              value: _finalDiseaseId,
                              options: _diseases,
                              onChanged: (v) =>
                                  setState(() => _finalDiseaseId = v),
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Catatan Diagnosis Akhir',
                              hint: 'Detail hasil lab',
                              value: _finalDiagnosis ?? '',
                              onChanged: (v) => _finalDiagnosis = v,
                              variant: 'outlined',
                            ),
                            SizedBox(height: 16.0),
                            TextFieldWidget(
                              label: 'Tindak Lanjut',
                              hint: 'Rencana tindak lanjut',
                              value: _followUp ?? '',
                              onChanged: (v) => _followUp = v,
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
                      : Text('Simpan Hasil Lab',
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
}
