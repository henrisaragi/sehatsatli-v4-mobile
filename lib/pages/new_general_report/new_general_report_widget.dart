import 'dart:convert';
import 'dart:io';

import '/components/photo_slot/photo_slot_widget.dart';
import '/components/step_indicator/step_indicator_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/report_repository.dart';
import 'new_general_report_model.dart';
export 'new_general_report_model.dart';

class NewGeneralReportWidget extends StatefulWidget {
  const NewGeneralReportWidget({
    super.key,
    this.clientId,
  });

  /// When set, edits the existing not-yet-synced `local_reports` row with
  /// this `client_id` instead of starting a blank report — lets officers fix
  /// up a draft/pending/failed report before it goes out, per CLAUDE.md §5's
  /// offline-first model (no separate edit-existing-report API exists; this
  /// just reloads the same local draft into the wizard).
  final String? clientId;

  static String routeName = 'NewGeneralReport';
  static String routePath = '/newGeneralReport';

  @override
  State<NewGeneralReportWidget> createState() => _NewGeneralReportWidgetState();
}

class _NewGeneralReportWidgetState extends State<NewGeneralReportWidget> {
  late NewGeneralReportModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // Cached master/location option lists — best-effort parsed (see
  // _extractList) since the exact JSON shape hasn't been confirmed against a
  // live response yet.
  List<Map<String, dynamic>> _upts = [];
  List<Map<String, dynamic>> _uptTypes = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _subdistricts = [];
  List<Map<String, dynamic>> _villages = [];
  List<Map<String, dynamic>> _insituOptions = [];
  List<Map<String, dynamic>> _exsituOptions = [];
  List<Map<String, dynamic>> _speciesCategories = [];
  List<Map<String, dynamic>> _protectedSpecies = [];
  List<Map<String, dynamic>> _deadSignOptions = [];
  List<Map<String, dynamic>> _liveSignOptions = [];

  // Fixed 4-option set per docs/general-report-field.md — not sourced from
  // any master-data cache.
  static const List<Map<String, dynamic>> _conservationTypeOptions = [
    {'id': 'LK Umum', 'name': 'LK Umum'},
    {'id': 'LK Khusus', 'name': 'LK Khusus'},
    {'id': 'Penangkaran', 'name': 'Penangkaran'},
    {'id': 'Lainnya', 'name': 'Lainnya'},
  ];
  List<Map<String, dynamic>> _diseases = [];

  bool _isLoadingDraft = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NewGeneralReportModel());
    _loadCachedOptions();
    // docs/general-report-field.md: latitude/longitude are "otomatis", not
    // manual-entry — fetch as soon as the form opens instead of waiting for
    // a button tap, so it's usually already populated by the time the
    // officer reaches Step 2.
    _fetchGps();
    if (widget.clientId != null) {
      _isLoadingDraft = true;
      _loadDraft(widget.clientId!);
    }
  }

  /// Reloads a not-yet-synced `local_reports` row into the wizard for
  /// editing. Any failure (row deleted, corrupt JSON, sqflite unavailable on
  /// web) just falls back to a blank form rather than crashing — the officer
  /// can still fill it out fresh.
  Future<void> _loadDraft(String clientId) async {
    try {
      final row = await SQLiteManager.instance.getLocalReport(clientId);
      final payloadJson = row?.payloadJson;
      if (payloadJson != null) {
        final payload = jsonDecode(payloadJson);
        if (payload is Map<String, dynamic>) {
          _model.hydrateFromPayload(payload, clientId);
          final files = payload['file'];
          if (files is List) {
            await _model.hydratePhotosFromBase64(files);
          }
        }
      }
    } catch (_) {
      // Fall back to a blank form.
    } finally {
      if (mounted) setState(() => _isLoadingDraft = false);
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _loadCachedOptions() async {
    final masterRepo = MasterRepository();
    final locationUser = await masterRepo.getCachedLocationUser();
    final masters = await masterRepo.getCachedMasters();
    final diseases = await masterRepo.getCachedDiseases();
    final upts = await masterRepo.getCachedUpts();
    final protectedSpecies = await masterRepo.getCachedProtectedSpecies();

    if (!mounted) return;
    setState(() {
      _provinces = _extractList(locationUser, ['provinces']);
      _districts = _extractList(locationUser, ['districts']);
      _subdistricts = _extractList(locationUser, ['subdistricts']);
      _villages = _extractList(locationUser, ['villages']);
      _uptTypes = _extractList(masters, ['upt_type']);
      _speciesCategories = _extractList(masters, ['species_category']);
      _protectedSpecies = protectedSpecies;
      _insituOptions = _extractList(masters, ['insitu_conservation']);
      _exsituOptions = _extractList(masters, ['exsitu_conservation']);
      _deadSignOptions = _extractList(masters, ['dead_sign']);
      _liveSignOptions = _extractList(masters, ['live_sign']);
      _diseases = _extractList(diseases, ['diseases', 'data']);
      _upts = _extractList(upts, ['upts', 'data']);
    });
  }

  List<Map<String, dynamic>> _extractList(dynamic data, List<String> keys) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      for (final key in keys) {
        final v = data[key];
        if (v is List) {
          return v
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  List<Map<String, dynamic>> _childrenOf(
    List<Map<String, dynamic>> list,
    dynamic parentId,
    List<String> parentKeys,
  ) {
    if (parentId == null) return [];
    for (final key in parentKeys) {
      final matches = list.where((e) => e[key] == parentId).toList();
      if (matches.isNotEmpty) return matches;
    }
    return [];
  }

  dynamic _optId(Map<String, dynamic> opt) => opt['id'] ?? opt['value'];

  String _optLabel(Map<String, dynamic> opt) =>
      (opt['name'] ?? opt['label'] ?? opt['text'] ?? opt['value'] ?? '')
          .toString();

  Future<void> _fetchGps() async {
    setState(() => _model.isFetchingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() {
        _model.locLatitude = position.latitude;
        _model.locLongitude = position.longitude;
      });
    } catch (_) {
      if (mounted) {
        showSnackbar(context,
            'Could not get GPS location — check permissions or enter it manually.');
      }
    } finally {
      if (mounted) setState(() => _model.isFetchingGps = false);
    }
  }

  Future<void> _saveDraft() async {
    final files = await _model.encodePhotoFiles();
    await ReportRepository().saveDraft(
      clientId: _model.clientId,
      payload: {..._model.toPayload(), 'file': files},
    );
    if (!mounted) return;
    showSnackbar(context, 'Saved as local draft.');
    context.pop();
  }

  Future<void> _submit() async {
    setState(() {
      _model.isSubmitting = true;
      _model.error = null;
    });
    final files = await _model.encodePhotoFiles();
    final result = await ReportRepository().submit(
      clientId: _model.clientId,
      payload: {..._model.toPayload(), 'file': files},
      token: FFAppState().accessToken,
      endpoint: ApiEndpoints.generalReportsSave,
    );
    if (!mounted) return;

    switch (result.status) {
      case ReportSubmitStatus.sentImmediately:
        setState(() => _model.isSubmitting = false);
        showSnackbar(context, 'Report submitted.');
        context.pop();
        break;
      case ReportSubmitStatus.queuedOffline:
        setState(() => _model.isSubmitting = false);
        showSnackbar(context, 'Saved locally — will sync when back online.');
        context.pop();
        break;
      case ReportSubmitStatus.failed:
        setState(() {
          _model.isSubmitting = false;
          _model.error = result.message ?? 'Failed to submit report.';
        });
        break;
    }
  }

  void _goNext() => setState(() {
        if (_model.currentStep < NewGeneralReportModel.totalSteps - 1) {
          _model.currentStep++;
        }
      });

  void _goBack() {
    if (_model.currentStep > 0) {
      setState(() => _model.currentStep--);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          children: [
            _buildHeader(context),
            TrainingModeBanner(),
            Expanded(
              child: _isLoadingDraft
                  ? Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StepIndicatorWidget(
                            currentStep: (_model.currentStep + 1).toDouble(),
                            totalSteps: NewGeneralReportModel.totalSteps,
                          ),
                          SizedBox(height: 24.0),
                          Text(
                            _stepTitle(_model.currentStep),
                            style: FlutterFlowTheme.of(context)
                                .titleLarge
                                .override(
                                  font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          SizedBox(height: 16.0),
                          _buildStepContent(context),
                          if (_model.error != null &&
                              _model.error!.isNotEmpty) ...[
                            SizedBox(height: 16.0),
                            Text(
                              _model.error!,
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                      color:
                                          FlutterFlowTheme.of(context).error),
                            ),
                          ],
                          SizedBox(height: 80.0),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _isLoadingDraft ? null : _buildFooter(context),
      ),
    );
  }

  String _stepTitle(int step) => const [
        'Data Pelapor',
        'Lokasi Kejadian',
        'Data Spesies',
        'Diagnosis Awal',
      ][step];

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        shape: BoxShape.rectangle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16.0, 34.0, 16.0, 24.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FlutterFlowIconButton(
                      borderRadius: 8.0,
                      buttonSize: 40.0,
                      fillColor: Colors.transparent,
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                      onPressed: _goBack,
                    ),
                    Text(
                      widget.clientId != null
                          ? 'Edit Draft Laporan'
                          : 'New General Report',
                      style: FlutterFlowTheme.of(context).titleLarge.override(
                            font: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold),
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ].divide(SizedBox(width: 8.0)),
                ),
                FlutterFlowIconButton(
                  borderRadius: 8.0,
                  buttonSize: 40.0,
                  fillColor: Colors.transparent,
                  icon: Icon(
                    Icons.save_outlined,
                    color: FlutterFlowTheme.of(context).primary,
                    size: 24.0,
                  ),
                  onPressed: _saveDraft,
                ),
              ].divide(SizedBox(width: 16.0)),
            ),
          ),
          Container(
            height: 1.0,
            decoration:
                BoxDecoration(color: FlutterFlowTheme.of(context).alternate),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_model.currentStep) {
      case 0:
        return _buildReporterStep(context);
      case 1:
        return _buildLocationStep(context);
      case 2:
        return _buildSpeciesStep(context);
      default:
        return _buildDiagnosisStep(context);
    }
  }

  Widget _buildFooter(BuildContext context) {
    final isLastStep =
        _model.currentStep == NewGeneralReportModel.totalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
            top: BorderSide(color: FlutterFlowTheme.of(context).alternate)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _goBack,
              icon: Icon(Icons.arrow_back_rounded,
                  size: 18.0,
                  color: FlutterFlowTheme.of(context).secondaryText),
              label: Text(_model.currentStep == 0 ? 'Batal' : 'Kembali'),
            ),
            if (!isLastStep) ...[
              Spacer(),
              _PrimaryButton(onTap: _goNext, label: 'Lanjut', compact: true),
            ] else ...[
              SizedBox(width: 12.0),
              Expanded(
                child: _OutlineButton(
                  onTap: _model.isSubmitting ? null : _saveDraft,
                  label: 'Simpan Draft',
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: _PrimaryButton(
                  onTap: _model.isSubmitting ? null : _submit,
                  label: 'Kirim Laporan',
                  loading: _model.isSubmitting,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReporterStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).accent3,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18.0, color: FlutterFlowTheme.of(context).info),
              SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'Data pelapor diambil otomatis dari akun yang sedang login.',
                  style: FlutterFlowTheme.of(context)
                      .bodySmall
                      .override(color: FlutterFlowTheme.of(context).info),
                ),
              ),
            ],
          ),
        ),
        _readonlyField(
            context: context,
            label: 'Nama Pelapor',
            value: _model.reporterName),
        _readonlyField(
            context: context,
            label: 'Jenis Kelamin',
            value: _model.reporterGender),
        _readonlyField(
            context: context,
            label: 'Pekerjaan',
            value: _model.reporterOccupation),
        _readonlyField(
            context: context, label: 'No. HP', value: _model.reporterPhone),
        _readonlyField(
            context: context, label: 'Alamat', value: _model.reporterAddress),
        _switchField(
          context: context,
          label: 'Ditemukan saat patroli rutin?',
          value: _model.reporterCaseFound,
          onChanged: (v) => setState(() => _model.reporterCaseFound = v),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  Widget _buildLocationStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropdown(
          context: context,
          label: 'UPT',
          value: _model.locUptId,
          options: _upts,
          onChanged: (v) => setState(() {
            _model.locUptId = v;
            final selected = _upts.firstWhere((u) => _optId(u) == v,
                orElse: () => <String, dynamic>{});
            _model.locUptName = _optLabel(selected);
          }),
        ),
        _dropdown(
          context: context,
          label: 'Tipe UPT',
          value: _model.locUptType,
          options: _uptTypes,
          onChanged: (v) => setState(() => _model.locUptType = v as String?),
        ),
        _textField(
          label: 'Nama Lokasi',
          hint: 'mis. SM Muara Angke',
          initialValue: _model.locLocationName,
          onChanged: (v) => _model.locLocationName = v,
        ),
        // docs/general-report-field.md: fixed 4-option select, not free
        // text — which of insitu/exsitu/other section shows below depends
        // on this value.
        _dropdown(
          context: context,
          label: 'Tipe Konservasi',
          value: _model.locConservationType,
          options: _conservationTypeOptions,
          onChanged: (v) => setState(() {
            _model.locConservationType = v as String?;
          }),
        ),
        if (_model.locConservationType == 'LK Khusus')
          _chipGroup(
            context: context,
            label: 'Konservasi In-situ',
            options: _insituOptions,
            selected: _model.locInsituConservation,
            onChanged: (v) => setState(() => _model.locInsituConservation = v),
          ),
        if (_model.locConservationType == 'Lainnya')
          _textField(
            label: 'In-situ Lainnya',
            hint: 'Sebutkan jika lainnya',
            initialValue: _model.locInsituOther,
            onChanged: (v) => _model.locInsituOther = v,
          ),
        if (_model.locConservationType == 'LK Umum')
          _chipGroup(
            context: context,
            label: 'Konservasi Ex-situ',
            options: _exsituOptions,
            selected: _model.locExsituConservation,
            onChanged: (v) => setState(() => _model.locExsituConservation = v),
          ),
        _dropdown(
          context: context,
          label: 'Provinsi',
          value: _model.locProvinceId,
          options: _provinces,
          onChanged: (v) => setState(() {
            _model.locProvinceId = v;
            _model.locDistrictId = null;
            _model.locSubdistrictId = null;
            _model.locVillageId = null;
          }),
        ),
        _dropdown(
          context: context,
          label: 'Kabupaten/Kota',
          value: _model.locDistrictId,
          options: _childrenOf(
              _districts, _model.locProvinceId, ['province_id', 'provinceId']),
          onChanged: (v) => setState(() {
            _model.locDistrictId = v;
            _model.locSubdistrictId = null;
            _model.locVillageId = null;
          }),
        ),
        _dropdown(
          context: context,
          label: 'Kecamatan',
          value: _model.locSubdistrictId,
          options: _childrenOf(_subdistricts, _model.locDistrictId,
              ['district_id', 'districtId']),
          onChanged: (v) => setState(() {
            _model.locSubdistrictId = v;
            _model.locVillageId = null;
          }),
        ),
        _dropdown(
          context: context,
          label: 'Desa/Kelurahan',
          value: _model.locVillageId,
          options: _childrenOf(_villages, _model.locSubdistrictId,
              ['subdistrict_id', 'subdistrictId']),
          onChanged: (v) => setState(() => _model.locVillageId = v),
        ),
        _textField(
          label: 'Deskripsi Lokasi',
          hint: 'Detail tambahan lokasi kejadian',
          initialValue: _model.locLocationDescription,
          onChanged: (v) => _model.locLocationDescription = v,
        ),
        // docs/general-report-field.md: latitude/longitude are "read only
        // teks: otomatis" — fetched automatically on page open (initState),
        // this button is just a manual refresh (e.g. after moving location
        // or granting permission late), not the only way to populate them.
        Row(
          children: [
            Expanded(
              child: _readonlyField(
                context: context,
                label: 'Latitude',
                value: _model.locLatitude?.toStringAsFixed(6),
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: _readonlyField(
                context: context,
                label: 'Longitude',
                value: _model.locLongitude?.toStringAsFixed(6),
              ),
            ),
          ],
        ),
        InkWell(
          onTap: _model.isFetchingGps ? null : _fetchGps,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              border: Border.all(color: FlutterFlowTheme.of(context).primary),
            ),
            alignment: Alignment.center,
            child: _model.isFetchingGps
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FlutterFlowTheme.of(context).primary),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 16.0,
                          color: FlutterFlowTheme.of(context).primary),
                      SizedBox(width: 6.0),
                      Text(
                        'Perbarui Lokasi GPS',
                        style: TextStyle(
                            color: FlutterFlowTheme.of(context).primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  Widget _buildSpeciesStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dropdown(
          context: context,
          label: 'Kategori',
          value: _model.specCategory,
          options: _speciesCategories,
          onChanged: (v) => setState(() => _model.specCategory = v as String?),
        ),
        _switchField(
          context: context,
          label: 'Satwa Dilindungi?',
          value: _model.specProtected,
          onChanged: (v) => setState(() {
            _model.specProtected = v;
            if (!v) _model.specSelectedId = null;
          }),
        ),
        if (_model.specProtected)
          _searchSelect(
            context: context,
            label: 'Satwa Dilindungi',
            hint: 'Cari nama satwa dilindungi...',
            options: _protectedSpecies,
            selectedId: _model.specSelectedId,
            selectedLabel: _model.specName,
            optionLabel: _optLabel,
            optionId: _optId,
            onSelected: (selected) {
              setState(() {
                _model.specSelectedId = _optId(selected);
                _model.specName = _optLabel(selected);
                // Confirmed field name via docs/sample-respons.md — species
                // master data has no separate "family" column, only this and
                // a broader `type` (e.g. "MAMALIA (MENYUSUI)"), so Famili is
                // deliberately left for manual entry, not auto-filled.
                _model.specLatinName =
                    (selected['latin_name'] ?? '').toString();
                final category = selected['category'];
                if (category != null) {
                  _model.specCategory = category.toString();
                }
              });
            },
          ),
        _textField(
          key: ValueKey('specName-${_model.specSelectedId}'),
          label: 'Nama Spesies',
          hint: 'mis. Harimau Sumatera',
          initialValue: _model.specName,
          onChanged: (v) => _model.specName = v,
        ),
        _textField(
          key: ValueKey('specLatinName-${_model.specSelectedId}'),
          label: 'Nama Latin',
          hint: 'mis. Panthera tigris sumatrae',
          initialValue: _model.specLatinName,
          onChanged: (v) => _model.specLatinName = v,
        ),
        _textField(
          label: 'Famili',
          hint: 'mis. Felidae',
          initialValue: _model.specFamily,
          onChanged: (v) => _model.specFamily = v,
        ),
        _textField(
          label: 'Usia',
          hint: 'mis. Dewasa',
          initialValue: _model.specAge,
          onChanged: (v) => _model.specAge = v,
        ),
        _textField(
          label: 'Populasi',
          hint: 'Jumlah individu',
          initialValue: _model.specPopulation?.toString(),
          keyboardType: TextInputType.number,
          onChanged: (v) => _model.specPopulation = int.tryParse(v),
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  Widget _buildDiagnosisStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _model.diagReportDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _model.diagReportDate = picked);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Tanggal Laporan',
              filled: true,
              fillColor: FlutterFlowTheme.of(context).secondaryBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide:
                    BorderSide(color: FlutterFlowTheme.of(context).alternate),
              ),
            ),
            child: Text(
              (_model.diagReportDate ?? DateTime.now())
                  .toIso8601String()
                  .split('T')
                  .first,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _textField(
                label: 'Jumlah Mati',
                hint: '0',
                initialValue: _model.diagDead.toString(),
                keyboardType: TextInputType.number,
                onChanged: (v) => _model.diagDead = int.tryParse(v) ?? 0,
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: _textField(
                label: 'Jumlah Hidup',
                hint: '0',
                initialValue: _model.diagLive.toString(),
                keyboardType: TextInputType.number,
                onChanged: (v) => _model.diagLive = int.tryParse(v) ?? 0,
              ),
            ),
          ],
        ),
        _chipGroup(
          context: context,
          label: 'Tanda Kematian',
          options: _deadSignOptions,
          selected: _model.diagDeadSign,
          onChanged: (v) => setState(() => _model.diagDeadSign = v),
        ),
        _textField(
          label: 'Tanda Kematian Lainnya',
          hint: 'Sebutkan jika lainnya',
          initialValue: _model.diagDeadSignOther,
          onChanged: (v) => _model.diagDeadSignOther = v,
        ),
        _chipGroup(
          context: context,
          label: 'Tanda Kehidupan',
          options: _liveSignOptions,
          selected: _model.diagLiveSign,
          onChanged: (v) => setState(() => _model.diagLiveSign = v),
        ),
        _textField(
          label: 'Tanda Kehidupan Lainnya',
          hint: 'Sebutkan jika lainnya',
          initialValue: _model.diagLiveSignOther,
          onChanged: (v) => _model.diagLiveSignOther = v,
        ),
        _textField(
          label: 'Kronologis',
          hint: 'Kronologi kejadian',
          initialValue: _model.diagChronological,
          onChanged: (v) => _model.diagChronological = v,
        ),
        _textField(
          label: 'Sampling',
          hint: 'Sampel yang diambil',
          initialValue: _model.diagSampling,
          onChanged: (v) => _model.diagSampling = v,
        ),
        _textField(
          label: 'Tindak Lanjut',
          hint: 'Rencana tindak lanjut',
          initialValue: _model.diagFollowUp,
          onChanged: (v) => _model.diagFollowUp = v,
        ),
        _textField(
          label: 'Diagnosis',
          hint: 'Catatan diagnosis awal',
          initialValue: _model.diagDiagnosis,
          onChanged: (v) => _model.diagDiagnosis = v,
        ),
        _dropdown(
          context: context,
          label: 'Diagnosis Sementara',
          value: _model.diagTemporaryDiagnosisId,
          options: _diseases,
          onChanged: (v) => setState(() => _model.diagTemporaryDiagnosisId = v),
        ),
        Text(
          'Foto Bukti',
          style: FlutterFlowTheme.of(context).labelMedium.override(
                font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                color: FlutterFlowTheme.of(context).primaryText,
              ),
        ),
        Row(
          children: [
            _photoSlot(index: 0, label: 'Subject'),
            SizedBox(width: 12.0),
            _photoSlot(index: 1, label: 'Environment'),
            SizedBox(width: 12.0),
            _photoSlot(index: 2, label: 'Detail'),
          ],
        ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  Widget _photoSlot({required int index, required String label}) {
    final path = _model.photoPaths[index];
    return InkWell(
      onTap: () => _pickPhoto(index),
      onLongPress: path == null
          ? null
          : () => setState(() => _model.photoPaths[index] = null),
      child: path == null
          ? PhotoSlotWidget(label: label)
          : ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.file(
                File(path),
                width: 100.0,
                height: 100.0,
                fit: BoxFit.cover,
              ),
            ),
    );
  }

  Future<void> _pickPhoto(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_rounded),
              title: Text('Ambil Foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded),
              title: Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (picked == null) return;

    // flutter_image_compress writes to a temp file separate from the
    // picked source, so nothing captured pre-compression lingers on disk.
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/report_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      quality: 70,
      minWidth: 1280,
      minHeight: 1280,
    );

    if (!mounted) return;
    setState(
        () => _model.photoPaths[index] = (compressed?.path ?? picked.path));
  }

  Widget _textField({
    Key? key,
    required String label,
    required String hint,
    required String? initialValue,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return TextFieldWidget(
      key: key,
      label: label,
      labelPresent: true,
      hint: hint,
      value: initialValue ?? '',
      onChanged: onChanged,
      keyboardType: keyboardType,
      variant: 'outlined',
    );
  }

  /// Displays a Step-1 reporter field pre-filled from the logged-in user —
  /// not editable, since it's the officer's own account data rather than
  /// something typed per report.
  Widget _readonlyField({
    required BuildContext context,
    required String label,
    required String? value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6.0),
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: FlutterFlowTheme.of(context).alternate),
          ),
          child: Text(
            (value == null || value.isEmpty) ? '-' : value,
            style: FlutterFlowTheme.of(context)
                .bodyMedium
                .override(color: FlutterFlowTheme.of(context).secondaryText),
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required BuildContext context,
    required String label,
    required dynamic value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<dynamic> onChanged,
  }) {
    // If a previously-selected value no longer matches any option (e.g. a
    // cascading parent changed), DropdownButtonFormField would assert.
    final validValue = options.any((o) => _optId(o) == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6.0),
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
          ),
        ),
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
                  value: _optId(opt), child: Text(_optLabel(opt))))
              .toList(),
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ],
    );
  }

  /// Select2-style searchable picker: the field itself just displays the
  /// current selection and opens a bottom sheet with a search box + filtered
  /// list on tap, instead of rendering every option inline like [_dropdown]
  /// — needed here since the protected-species list can run into the
  /// hundreds of entries.
  Widget _searchSelect({
    required BuildContext context,
    required String label,
    required String hint,
    required List<Map<String, dynamic>> options,
    required dynamic selectedId,
    required String? selectedLabel,
    required String Function(Map<String, dynamic>) optionLabel,
    required dynamic Function(Map<String, dynamic>) optionId,
    required ValueChanged<Map<String, dynamic>> onSelected,
  }) {
    final hasSelection = selectedId != null && (selectedLabel ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6.0),
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: options.isEmpty
              ? null
              : () => _openSearchSelectSheet(
                    context: context,
                    label: label,
                    hint: hint,
                    options: options,
                    optionLabel: optionLabel,
                    optionId: optionId,
                    onSelected: onSelected,
                  ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: FlutterFlowTheme.of(context).alternate),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasSelection
                        ? selectedLabel!
                        : (options.isEmpty
                            ? 'Belum ada data cache'
                            : 'Pilih $label'),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          color: hasSelection
                              ? FlutterFlowTheme.of(context).primaryText
                              : FlutterFlowTheme.of(context).secondaryText,
                        ),
                  ),
                ),
                Icon(Icons.search,
                    size: 18.0,
                    color: FlutterFlowTheme.of(context).secondaryText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSearchSelectSheet({
    required BuildContext context,
    required String label,
    required String hint,
    required List<Map<String, dynamic>> options,
    required String Function(Map<String, dynamic>) optionLabel,
    required dynamic Function(Map<String, dynamic>) optionId,
    required ValueChanged<Map<String, dynamic>> onSelected,
  }) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (sheetContext) {
        var query = '';
        var filtered = options;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.4,
                maxChildSize: 0.92,
                expand: false,
                builder: (context, scrollController) => Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                      child: Text(
                        'Pilih $label',
                        style: FlutterFlowTheme.of(context)
                            .titleMedium
                            .override(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setSheetState(() {
                          query = v;
                          filtered = query.isEmpty
                              ? options
                              : options
                                  .where((o) => optionLabel(o)
                                      .toLowerCase()
                                      .contains(query.toLowerCase()))
                                  .toList();
                        }),
                        decoration: InputDecoration(
                          hintText: hint,
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ditemukan',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => Divider(
                                  height: 1.0,
                                  color:
                                      FlutterFlowTheme.of(context).alternate),
                              itemBuilder: (context, index) {
                                final opt = filtered[index];
                                return ListTile(
                                  title: Text(optionLabel(opt),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium),
                                  onTap: () =>
                                      Navigator.of(sheetContext).pop(opt),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null) onSelected(selected);
  }

  Widget _chipGroup({
    required BuildContext context,
    required String label,
    required List<Map<String, dynamic>> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    if (options.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 6.0),
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
          ),
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: options.map((opt) {
            final optLabel = _optLabel(opt);
            final isSelected = selected.contains(optLabel);
            return FilterChip(
              label: Text(optLabel),
              selected: isSelected,
              onSelected: (v) {
                final next = List<String>.from(selected);
                if (v) {
                  next.add(optLabel);
                } else {
                  next.remove(optLabel);
                }
                onChanged(next);
              },
              selectedColor: FlutterFlowTheme.of(context).primary.withAlpha(38),
              checkmarkColor: FlutterFlowTheme.of(context).primary,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _switchField({
    required BuildContext context,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: FlutterFlowTheme.of(context)
                .bodyMedium
                .override(color: FlutterFlowTheme.of(context).primaryText),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: FlutterFlowTheme.of(context).primary,
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.onTap,
    required this.label,
    this.loading = false,
    this.compact = false,
  });

  final VoidCallback? onTap;
  final String label;
  final bool loading;

  /// Shrinks the button to fit its label + padding instead of stretching
  /// full-width — used for the mid-wizard "Lanjut" button, which sits
  /// right-aligned next to "Kembali" rather than filling the footer row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          height: compact ? 40.0 : 48.0,
          padding: compact ? EdgeInsets.symmetric(horizontal: 24.0) : null,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary,
            borderRadius: BorderRadius.circular(10.0),
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FlutterFlowTheme.of(context).onPrimary),
                )
              : Text(
                  label,
                  style: (compact
                          ? FlutterFlowTheme.of(context).labelMedium
                          : FlutterFlowTheme.of(context).labelLarge)
                      .override(
                    color: FlutterFlowTheme.of(context).onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.onTap, required this.label});

  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          height: 48.0,
          decoration: BoxDecoration(
            border: Border.all(color: FlutterFlowTheme.of(context).primary),
            borderRadius: BorderRadius.circular(10.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).labelLarge.override(
                  color: FlutterFlowTheme.of(context).primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }
}
