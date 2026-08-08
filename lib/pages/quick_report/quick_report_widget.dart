import '/components/date_field/date_field_widget.dart';
import '/components/search_select/search_select_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/api_endpoints.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../full_report/full_report_widget.dart';

/// Short create-only form — revisi.md §1 "laporan-umum/cepat/new". Submits
/// once via the same flat-payload `general-reports/save` endpoint the old
/// wizard used, then always navigates forward to [FullReportWidget] keyed by
/// the just-generated `clientId` (never a server id — offline-safe, a
/// server id may not exist yet if this device is offline right now) so the
/// officer can immediately continue into the full Investigasi tab.
class QuickReportWidget extends StatefulWidget {
  const QuickReportWidget({super.key});

  static String routeName = 'QuickReport';
  static String routePath = '/quickReport';

  @override
  State<QuickReportWidget> createState() => _QuickReportWidgetState();
}

class _QuickReportWidgetState extends State<QuickReportWidget> {
  DateTime? _reportDate = DateTime.now();
  String _location = '';
  bool _protected = false;
  String _speciesName = '';
  dynamic _speciesId;
  String? _speciesLabel;
  String _dead = '';
  String _live = '';
  String _description = '';

  List<Map<String, dynamic>> _speciesOptions = [];
  bool _loadingSpecies = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpecies();
  }

  Future<void> _loadSpecies() async {
    setState(() => _loadingSpecies = true);
    final masterRepo = MasterRepository();
    var options = await masterRepo.getCachedProtectedSpecies();
    if (options.isEmpty) {
      // Defensive fallback — an empty protected-only list would otherwise
      // leave a required field permanently unselectable.
      final all = await masterRepo.getCachedSpecies();
      options = all is List
          ? all.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
    }
    if (!mounted) return;
    setState(() {
      _speciesOptions = options;
      _loadingSpecies = false;
    });
  }

  dynamic _optId(Map<String, dynamic> opt) => opt['id'] ?? opt['value'];

  String _optLabel(Map<String, dynamic> opt) =>
      (opt['name'] ?? opt['label'] ?? opt['text'] ?? opt['value'] ?? '')
          .toString();

  bool get _isValid {
    if (_reportDate == null) return false;
    if (_location.trim().isEmpty) return false;
    if (_protected) {
      if (_speciesId == null) return false;
    } else {
      if (_speciesName.trim().isEmpty) return false;
    }
    if (int.tryParse(_dead) == null) return false;
    if (int.tryParse(_live) == null) return false;
    if (_description.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final currentUser = FFAppState().currentUser;
    final user = currentUser is Map ? Map<String, dynamic>.from(currentUser) : const {};
    final userId = user['id'];
    final reportDate =
        (_reportDate ?? DateTime.now()).toIso8601String().split('T').first;

    final clientId = ReportRepository().newClientId();
    final payload = <String, dynamic>{
      'id': 0,
      'creator': userId,
      'updater': userId,
      'training': user['trained'] == true || user['trained'] == 1 || user['trained'] == '1',
      'status': 1,
      'user_id': userId,
      'report_code': '',
      'report_date': reportDate,
      'location': _location.trim(),
      'protected': _protected,
      'protected_species': _protected ? 1 : 0,
      'species_id': _protected ? _speciesId : null,
      'species_name': _protected ? '' : _speciesName.trim(),
      'dead': int.tryParse(_dead) ?? 0,
      'live': int.tryParse(_live) ?? 0,
      'description': _description.trim(),
      'reporter_id': userId,
    };

    final result = await ReportRepository().submit(
      clientId: clientId,
      payload: payload,
      token: FFAppState().accessToken,
      endpoint: ApiEndpoints.generalReportsSave,
    );

    if (!mounted) return;

    if (result.status == ReportSubmitStatus.failed) {
      setState(() {
        _isSubmitting = false;
        _error = result.message ?? 'Error, data belum disimpan';
      });
      return;
    }

    setState(() => _isSubmitting = false);
    showSnackbar(
      context,
      result.status == ReportSubmitStatus.sentImmediately
          ? 'Data berhasil disimpan.'
          : 'Disimpan secara lokal — akan disinkronkan saat online.',
    );
    context.pushNamed(
      FullReportWidget.routeName,
      queryParameters: {
        'clientId': serializeParam(clientId, ParamType.String),
      }.withoutNulls,
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: EdgeInsets.only(bottom: 6.0),
        child: Text(
          text,
          style: FlutterFlowTheme.of(context).labelMedium.override(
                font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                color: FlutterFlowTheme.of(context).primaryText,
              ),
        ),
      );

  Widget _multilineField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    int maxLength = 180,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: FlutterFlowTheme.of(context).alternate),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: TextFormField(
            initialValue: value,
            maxLines: 3,
            maxLength: maxLength,
            onChanged: onChanged,
            style: FlutterFlowTheme.of(context).bodyMedium,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Type here...',
              counterStyle: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: FlutterFlowTheme.of(context).secondaryText),
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return TextFieldWidget(
      label: label,
      hint: '0',
      value: value,
      keyboardType: TextInputType.number,
      variant: 'outlined',
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: Text(
          'Laporan Cepat',
          style: FlutterFlowTheme.of(context).titleLarge,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            TrainingModeBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          _error!,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(color: FlutterFlowTheme.of(context).error),
                        ),
                      ),
                    _sectionLabel('Tanggal Laporan'),
                    DateFieldWidget(
                      label: 'Tanggal Laporan',
                      date: _reportDate,
                      onChanged: (d) => setState(() => _reportDate = d),
                    ),
                    SizedBox(height: 16.0),
                    _multilineField(
                      label: 'Lokasi',
                      value: _location,
                      onChanged: (v) => setState(() => _location = v),
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Apakah hewan/satwa dilindungi?',
                          style: FlutterFlowTheme.of(context).bodyLarge,
                        ),
                        Switch(
                          value: _protected,
                          onChanged: (v) => setState(() {
                            _protected = v;
                            if (!v) {
                              _speciesId = null;
                              _speciesLabel = null;
                            }
                          }),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.0),
                    if (_protected)
                      _loadingSpecies
                          ? Center(child: CircularProgressIndicator())
                          : SearchSelectWidget(
                              label: 'Jenis Satwa',
                              hint: 'Cari nama satwa...',
                              options: _speciesOptions,
                              selectedId: _speciesId,
                              selectedLabel: _speciesLabel,
                              optionLabel: _optLabel,
                              optionId: _optId,
                              onSelected: (selected) => setState(() {
                                _speciesId = _optId(selected);
                                _speciesLabel = _optLabel(selected);
                              }),
                            )
                    else
                      TextFieldWidget(
                        label: 'Nama Spesies',
                        hint: 'mis. Harimau Sumatera',
                        value: _speciesName,
                        variant: 'outlined',
                        onChanged: (v) => setState(() => _speciesName = v),
                      ),
                    SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: _numberField(
                            label: 'Jumlah Mati',
                            value: _dead,
                            onChanged: (v) => setState(() => _dead = v),
                          ),
                        ),
                        SizedBox(width: 12.0),
                        Expanded(
                          child: _numberField(
                            label: 'Jumlah Hidup/Sakit',
                            value: _live,
                            onChanged: (v) => setState(() => _live = v),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.0),
                    _multilineField(
                      label: 'Deskripsi',
                      value: _description,
                      onChanged: (v) => setState(() => _description = v),
                    ),
                    SizedBox(height: 24.0),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => context.pop(),
                            child: Text('Batal'),
                          ),
                        ),
                        SizedBox(width: 12.0),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (_isValid && !_isSubmitting) ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FlutterFlowTheme.of(context).primary,
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 18.0,
                                    height: 18.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
