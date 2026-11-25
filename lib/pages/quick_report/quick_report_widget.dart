import 'package:flutter/material.dart';

import '/components/search_select/search_select_widget.dart';
import '/components/simple_dropdown/simple_dropdown_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../data/models/laporan_fields.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../full_report/full_report_widget.dart';
import '../report_form/investigasi_form.dart';
import '../report_form/report_form_fields.dart';

/// New laporan — the first two wizard steps of the web app, done together so
/// a field officer can finish a report offline in one sitting:
/// 1. Jenis satwa (P.106 species from the cached master, or a manual local
///    name) + kelompok umur → `POST laporan`
/// 2. Investigasi + photos → `PUT laporan/{id}/investigasi`
///
/// "Lanjut" saves a local draft (CLAUDE.md §8); [clientId] resumes one.
class QuickReportWidget extends StatefulWidget {
  const QuickReportWidget({super.key, this.clientId});

  final String? clientId;

  static String routeName = 'QuickReport';
  static String routePath = '/quickReport';

  @override
  State<QuickReportWidget> createState() => _QuickReportWidgetState();
}

class _QuickReportWidgetState extends State<QuickReportWidget> {
  final _repository = ReportRepository();
  late final String _clientId = widget.clientId ?? _repository.newClientId();

  int _step = 0;
  bool _dilindungi = true;
  Map<String, dynamic>? _spesies;
  String _namaJenisLokal = '';
  String? _kelompokUmur;
  final InvestigasiFormData _investigasi = InvestigasiFormData();

  List<Map<String, dynamic>> _spesiesOptions = [];
  List<Map<String, dynamic>> _penyakitOptions = [];
  bool _loading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final masters = MasterRepository();
    _spesiesOptions = await masters.getCachedSpesies();
    _penyakitOptions = await masters.getCachedPenyakit();
    if (widget.clientId != null) await _loadDraft(widget.clientId!);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDraft(String clientId) async {
    final row = await SQLiteManager.instance.getLocalReport(clientId);
    if (row == null || row.syncStatus != 'draft') return;
    final draft = jsonDecode(row.payloadJson ?? '{}') as Map<String, dynamic>;
    _spesies = draft['spesies'] is Map ? Map<String, dynamic>.from(draft['spesies']) : null;
    _namaJenisLokal = draft['nama_jenis_lokal']?.toString() ?? '';
    _dilindungi = _namaJenisLokal.isEmpty;
    _kelompokUmur = draft['kelompok_umur'] as String?;
    if (draft['investigasi_draft'] is Map) {
      _investigasi.loadDraft(Map<String, dynamic>.from(draft['investigasi_draft']));
    }
  }

  bool get _isStep1Valid =>
      _kelompokUmur != null &&
      (_dilindungi ? _spesies != null : _namaJenisLokal.trim().isNotEmpty);

  Map<String, dynamic> get _createPayload => {
        if (_dilindungi) 'spesies_id': _spesies!['id'] else 'nama_jenis_lokal': _namaJenisLokal.trim(),
        'kelompok_umur': _kelompokUmur,
      };

  Map<String, dynamic> get _speciesDisplay => {
        if (_dilindungi && _spesies != null)
          'spesies': {
            'id': _spesies!['id'],
            'scientific_name': _spesies!['scientific_name'],
            'local_name': _spesies!['local_name'],
          },
        'status_perlindungan': _dilindungi ? 'dilindungi' : 'tidak_dilindungi',
      };

  Future<void> _next() async {
    await _repository.saveDraft(clientId: _clientId, payload: {
      ..._speciesDisplay,
      ..._createPayload,
      'investigasi_draft': _investigasi.toDraft(),
    });
    if (mounted) setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (!_investigasi.isValid || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await _repository.createWithInvestigasi(
      clientId: _clientId,
      createPayload: _createPayload,
      display: {..._speciesDisplay, ..._investigasi.toDisplay()},
      investigasi: _investigasi.toPayload(),
      photoPaths: _investigasi.photoPaths,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Queued locally either way; a server rejection is shown (with retry) on
    // the detail page.
    showSnackbar(
      context,
      switch (result.status) {
        ReportSubmitStatus.sent => 'Laporan terkirim.',
        ReportSubmitStatus.queuedOffline => 'Tersimpan di perangkat — dikirim otomatis saat online.',
        ReportSubmitStatus.failed => 'Server menolak laporan: ${result.message ?? '-'}',
      },
    );
    context.pushReplacementNamed(
      FullReportWidget.routeName,
      queryParameters: {'clientId': serializeParam(_clientId, ParamType.String)}.withoutNulls,
    );
  }

  String _spesiesLabel(Map<String, dynamic> option) {
    final local = option['local_name']?.toString() ?? '';
    final scientific = option['scientific_name']?.toString() ?? '';
    if (local.isEmpty) return scientific;
    return scientific.isEmpty ? local : '$local ($scientific)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        title: Text('Laporan Baru', style: theme.titleLarge),
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _StepHeader(step: _step),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20.0),
                      child: _step == 0 ? _buildJenis(theme) : _buildInvestigasi(),
                    ),
                  ),
                  _buildNavBar(theme),
                ],
              ),
      ),
    );
  }

  Widget _buildJenis(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormSwitchRow(
          label: 'Jenis Dilindungi (P.106/MENLHK/SETJEN/KUM.1/12/2018)',
          value: _dilindungi,
          onChanged: (v) => setState(() => _dilindungi = v),
        ),
        if (_dilindungi)
          SearchSelectWidget(
            label: 'Spesies *',
            hint: _spesiesOptions.isEmpty
                ? 'Daftar spesies belum tersedia offline — sambungkan internet sekali'
                : 'Cari spesies...',
            options: _spesiesOptions,
            selectedId: _spesies?['id'],
            selectedLabel: _spesies == null ? null : _spesiesLabel(_spesies!),
            optionLabel: _spesiesLabel,
            optionId: (o) => o['id'],
            onSelected: (selected) => setState(() => _spesies = selected),
          )
        else
          TextFieldWidget(
            label: 'Nama Jenis (Lokal) *',
            hint: 'Contoh: Burung kutilang',
            value: _namaJenisLokal,
            variant: 'outlined',
            onChanged: (v) => setState(() => _namaJenisLokal = v),
          ),
        SimpleDropdownWidget(
          label: 'Kelompok Umur *',
          value: _kelompokUmur,
          options: kelompokUmurOptions,
          optionLabel: (o) => o['label'].toString(),
          optionId: (o) => o['id'],
          onChanged: (v) => setState(() => _kelompokUmur = v as String?),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  Widget _buildInvestigasi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(_error!,
                style: FlutterFlowTheme.of(context)
                    .bodyMedium
                    .override(color: FlutterFlowTheme.of(context).error)),
          ),
        InvestigasiFormFields(
          data: _investigasi,
          penyakitOptions: _penyakitOptions,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildNavBar(FlutterFlowTheme theme) {
    final isLast = _step == 1;
    final canContinue = isLast ? _investigasi.isValid : _isStep1Valid;
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(top: BorderSide(color: theme.alternate)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => isLast ? setState(() => _step = 0) : context.pop(),
                  child: Text(isLast ? 'Kembali' : 'Batal'),
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                flex: 2,
                child: FormSubmitButton(
                  label: isLast ? 'Kirim Laporan' : 'Lanjut',
                  isSaving: _isSubmitting,
                  onPressed: canContinue ? (isLast ? _submit : _next) : null,
                ),
              ),
            ],
          ),
          if (!canContinue) FormMissingHint(),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  static const _titles = ['Jenis Satwa', 'Investigasi'];

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(bottom: BorderSide(color: theme.alternate)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (step + 1) / _titles.length,
            color: theme.primary,
            backgroundColor: theme.alternate,
          ),
          SizedBox(height: 8.0),
          Text(
            'Langkah ${step + 1} dari ${_titles.length}: ${_titles[step]}',
            style: theme.titleSmall.override(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
