import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/date_field/date_field_widget.dart';
import '/components/multi_image_picker/multi_image_picker_widget.dart';
import '/components/repeater_list/repeater_list_widget.dart';
import '/components/search_select/search_select_widget.dart';
import '/components/simple_dropdown/simple_dropdown_widget.dart';
import '/components/tag_multi_select/tag_multi_select_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../backend/sqlite/sqlite_manager.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/option_list.dart';
import '../../data/models/user_profile_fields.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../report_history/report_history_widget.dart';

/// Full Report — replaces the old read-only `ReportDetailViewWidget` plus
/// the 3 separately-routed `ReportVerificationWidget`/`ReportLabWidget`/
/// `ReportInvestigationWidget` pages with ONE page, 4 tabs sharing a single
/// `_currentReport` state (revisi.md §2, plan §6.2-6.4).
///
/// Accepts both [clientId] (unsynced local draft) and [reportId] (synced,
/// server-known report) per the app's existing navigation convention (see
/// `dashboard_widget.dart`'s `_recentReportsSection` onTap).
class FullReportWidget extends StatefulWidget {
  const FullReportWidget({super.key, this.clientId, this.reportId});

  final String? clientId;
  final String? reportId;

  static String routeName = 'FullReport';
  static String routePath = '/fullReport';

  @override
  State<FullReportWidget> createState() => _FullReportWidgetState();
}

class _FullReportWidgetState extends State<FullReportWidget>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  bool _isLoading = true;
  String? _loadError;
  bool _isDeleting = false;

  String? _clientId;
  int? _serverId;
  String? _reportCode;

  /// Flat top-level fields (Tab 1's own contract, matching
  /// `NewGeneralReportModel.toPayload()`) merged with sectioned
  /// `verification`/`lab`/`investigation`/`media` data from either the local
  /// cached snapshot or a live `getOne` fetch.
  Map<String, dynamic> _currentReport = {};

  bool get _hasLocalRow => _clientId != null && _localRowSeen;
  bool _localRowSeen = false;

  Map<String, dynamic>? _currentUserRaw;

  // ---- Master data caches ----
  List<Map<String, dynamic>> _speciesCategories = [];
  List<Map<String, dynamic>> _animalTypes = [];
  List<Map<String, dynamic>> _ageGroups = [];
  List<Map<String, dynamic>> _clinicalSigns = [];
  List<Map<String, dynamic>> _caseTypes = [];
  List<Map<String, dynamic>> _genders = [];
  List<Map<String, dynamic>> _conservationTypes = [];
  List<Map<String, dynamic>> _conservationInstitutions = [];
  List<Map<String, dynamic>> _uptTypes = [];
  List<Map<String, dynamic>> _upts = [];
  List<Map<String, dynamic>> _protectedSpecies = [];
  List<Map<String, dynamic>> _diseases = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _subdistricts = [];
  List<Map<String, dynamic>> _villages = [];

  List<Map<String, dynamic>> get _liveSignOptions =>
      _clinicalSigns.where((o) => o['type']?.toString() == 'Live').toList();
  List<Map<String, dynamic>> get _deadSignOptions =>
      _clinicalSigns.where((o) => o['type']?.toString() == 'Dead').toList();
  List<Map<String, dynamic>> get _insituOptions => _conservationInstitutions
      .where((o) => o['conservation_type']?.toString() == 'IS')
      .toList();
  List<Map<String, dynamic>> get _exsituOptions => _conservationInstitutions
      .where((o) => o['conservation_type']?.toString() == 'ES')
      .toList();

  /// revisi.md bug note #3: filter `id < 3`, but fall back to the full list
  /// if that filter yields nothing (fragile if `case_types` ids ever turn
  /// out non-numeric — flagged in the plan as needing live confirmation).
  List<Map<String, dynamic>> get _temporaryDiagnosisOptions {
    final filtered = _caseTypes.where((o) {
      final id = o['id'];
      return id is int && id < 3;
    }).toList();
    return filtered.isNotEmpty ? filtered : _caseTypes;
  }

  // ---- Tab 1 (Investigasi) is itself a 4-step wizard, one page per step
  // (not a single long scroll) ----
  static const List<String> _t1StepTitles = [
    'Data Species',
    'Tahap Investigasi',
    'Data Administrasi — Lokasi',
    'Data Administrasi — Pelapor',
  ];
  int _t1Step = 0;

  // ---- Tab 1 (Investigasi) field state ----
  String? _t1Category;
  bool _t1Protected = true;
  dynamic _t1ProtectedSpeciesId;
  String? _t1SpeciesName;
  String? _t1SpeciesLatinName;
  String? _t1SpeciesFamily;
  String? _t1SpeciesAge;
  int? _t1Population;

  DateTime? _t1ReportDate;
  int _t1Dead = 0;
  List<dynamic> _t1DeadSign = [];
  String? _t1DeadSignOther;
  int _t1Live = 0;
  List<dynamic> _t1LiveSign = [];
  String? _t1LiveSignOther;
  String? _t1Chronological;
  String? _t1Sampling;
  String? _t1FollowUp;
  dynamic _t1TemporaryDiagnosisId;
  String? _t1Diagnosis;
  List<String> _t1NewPhotoPaths = [];

  String? _t1ReporterName;
  String? _t1ReporterGender;
  String? _t1ReporterOccupation;
  String? _t1ReporterPhone;
  String? _t1ReporterAddress;
  // No UI to edit this — matches the web app's hidden `case_found` input
  // (GeneralReportReporterSimpleForm.jsx), which only round-trips whatever
  // value the report already has so re-saving from here doesn't wipe it.
  String? _t1ReporterCaseFound;

  dynamic _t1UptId;
  String? _t1UptType;
  String? _t1LocationName;
  String? _t1LocationDescription;
  String? _t1ConservationType;
  List<dynamic> _t1Insitu = [];
  String? _t1InsituOther;
  List<dynamic> _t1Exsitu = [];
  String? _t1ExsituOther;
  double? _t1Latitude;
  double? _t1Longitude;
  bool _t1FetchingGps = false;
  dynamic _t1ProvinceId;
  dynamic _t1DistrictId;
  dynamic _t1SubdistrictId;
  dynamic _t1VillageId;

  bool _savingTab1 = false;
  String? _tab1Error;

  // ---- Tab 2 (Verifikasi) ----
  DateTime? _t2VerifiedDate;
  bool _t2Verified = false;
  String? _t2Verification;
  dynamic _t2TemporaryDiseaseId;
  String? _t2Sampling;
  dynamic _t2Action;
  String? _t2DoctorInformation;
  List<Map<String, dynamic>> _t2InvolvedDoctors = [];
  List<String> _t2NewPhotoPaths = [];
  bool _savingTab2 = false;
  String? _tab2Error;

  // ---- Tab 3 (Lab) ----
  dynamic _t3FinalDiseaseId;
  String? _t3FinalDiagnosis;
  dynamic _t3FollowUp;
  bool _savingTab3 = false;
  String? _tab3Error;

  // ---- Tab 4 (Investigasi Lanjutan) ----
  DateTime? _t4DateFrom;
  DateTime? _t4DateTo;
  String? _t4InspectionMethod;
  List<Map<String, dynamic>> _t4Evidence = [];
  List<String> _t4NewPhotoPaths = [];
  String? _t4FollowUpCarriedOut;
  String? _t4AdditionalInformation;
  List<Map<String, dynamic>> _t4DataInvestigation = [];
  bool _savingTab4 = false;
  String? _tab4Error;

  bool get _isDoctor => FFAppState().isDoctor;

  @override
  void initState() {
    super.initState();
    _clientId = widget.clientId;
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      Map<String, dynamic>? localPayload;
      if (_clientId != null) {
        final row = await SQLiteManager.instance.getLocalReport(_clientId!);
        if (row != null) {
          _localRowSeen = true;
          _serverId = row.serverId;
          _reportCode = row.reportCode;
          final payloadJson = row.payloadJson;
          if (payloadJson != null) {
            final decoded = jsonDecode(payloadJson);
            if (decoded is Map<String, dynamic>) localPayload = decoded;
          }
        }
      }

      final token = FFAppState().accessToken;
      final fetchId = _serverId ?? int.tryParse(widget.reportId ?? '');
      Map<String, dynamic>? remote;
      if (fetchId != null && token != null) {
        remote = await ReportRepository().fetchOne(id: fetchId, token: token);
      }

      if (localPayload == null && remote == null) {
        setState(() {
          _isLoading = false;
          _loadError = widget.clientId == null && widget.reportId != null
              ? 'Tidak tersedia offline — sambungkan ke internet untuk membuka laporan ini.'
              : 'Laporan tidak ditemukan.';
        });
        return;
      }

      _currentReport = {...?localPayload, if (remote != null) ...remote};
      if (remote != null) {
        _serverId = (remote['id'] as int?) ?? _serverId;
        _reportCode = (remote['report_code'] as String?) ?? _reportCode;
        final remoteClientId = remote['client_id']?.toString();
        // Most existing reports predate this app's offline-first client_id
        // scheme and come back with `client_id: null` from the server
        // (confirmed live 2026-08-08 — every pre-existing test report had
        // this). Without a fallback here, `_clientId` would stay null
        // forever for those reports, which permanently blocks Tabs 2-4
        // (gated on a local_reports row keyed by client_id) and the delete
        // button (which requires clientId) for the vast majority of real
        // reports — not just a rare edge case. Since this report already
        // has a real `_serverId`, a fresh LOCAL-only client_id is safe to
        // mint here: it's only ever used for this device's own SQLite
        // bookkeeping/offline-queue identity, never sent to a create
        // endpoint (Tabs 2-4 submit against `_serverId`, not client_id).
        _clientId ??=
            (remoteClientId != null && remoteClientId.isNotEmpty)
                ? remoteClientId
                : ReportRepository().newClientId();

        // Materialize a local cache row for a report opened for the first
        // time on this device via reportId only, so Tabs 2-4 (which require
        // a local_reports row to exist) work offline from now on.
        if (!_localRowSeen && _clientId != null) {
          await SQLiteManager.instance.upsertLocalReport(
            clientId: _clientId!,
            payloadJson: jsonEncode(_currentReport),
            syncStatus: 'synced',
            serverId: _serverId,
            reportCode: _reportCode,
          );
          _localRowSeen = true;
        }
      }

      final currentUser = FFAppState().currentUser;
      _currentUserRaw =
          currentUser is Map ? Map<String, dynamic>.from(currentUser) : null;

      await _loadMasters();
      _hydrateTab1();
      _hydrateTab2();
      _hydrateTab3();
      _hydrateTab4();

      if (!mounted) return;
      setState(() => _isLoading = false);
      if (_t1Latitude == null || _t1Longitude == null) _fetchGps();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Gagal memuat laporan.';
      });
    }
  }

  Future<void> _loadMasters() async {
    final masterRepo = MasterRepository();
    final masters = await masterRepo.getCachedMasters();
    final species = await masterRepo.getCachedProtectedSpecies();
    final diseases = await masterRepo.getCachedDiseases();
    final upts = await masterRepo.getCachedUpts();
    final locationUser = await masterRepo.getCachedLocationUser();

    _speciesCategories = extractOptionList(masters, ['species_category']);
    _animalTypes = extractOptionList(masters, ['animal_types']);
    _ageGroups = extractOptionList(masters, ['age_groups']);
    _clinicalSigns = extractOptionList(masters, ['clinical_signs']);
    _caseTypes = extractOptionList(masters, ['case_types']);
    _genders = extractOptionList(masters, ['genders']);
    _conservationTypes = extractOptionList(masters, ['conservation_types']);
    _conservationInstitutions =
        extractOptionList(masters, ['conservation_institutions']);
    _uptTypes = extractOptionList(masters, ['upt_type']);
    _protectedSpecies = species;
    _diseases = extractOptionList(diseases, ['diseases', 'data']);
    _upts = extractOptionList(upts, ['upts', 'data']);
    _provinces = extractOptionList(locationUser, ['provinces']);
    _districts = extractOptionList(locationUser, ['districts']);
    _subdistricts = extractOptionList(locationUser, ['subdistricts']);
    _villages = extractOptionList(locationUser, ['villages']);
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

  Map<String, dynamic>? _section(String key) {
    final value = _currentReport[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  List<Map<String, dynamic>> _mediaItems() {
    final raw = _currentReport['media'] ??
        _currentReport['photos'] ??
        _currentReport['files'];
    return extractOptionList(raw, ['media', 'photos', 'files', 'data']);
  }

  String? _mediaUrl(Map<String, dynamic> item) {
    final v =
        item['url'] ?? item['path'] ?? item['file_url'] ?? item['media_url'];
    return v?.toString();
  }

  // ---- Tab hydration: prefer nested getOne sections, fall back to flat
  // Tab-1-shaped local payload for a not-yet-synced draft. ----

  void _hydrateTab1() {
    final species = _section('species');
    final diagnoses = _section('diagnoses');
    final reporter = _section('reporter');
    final location = _section('locations') ?? _section('location');
    final upt = _section('upt');

    dynamic pick(String key, {Map<String, dynamic>? from}) =>
        from?[key] ?? _currentReport[key];

    _t1Category = pick('category', from: species)?.toString();
    _t1Protected = (pick('protected', from: species) ?? true) == true;
    _t1ProtectedSpeciesId =
        pick('protected_species', from: species) ?? pick('species_id');
    _t1SpeciesName = pick('species_name', from: species)?.toString();
    _t1SpeciesLatinName = pick('species_latin_name', from: species)?.toString();
    _t1SpeciesFamily = pick('species_family', from: species)?.toString();
    _t1SpeciesAge = pick('species_age', from: species)?.toString();
    final population = pick('population', from: species);
    _t1Population =
        population is int ? population : int.tryParse('$population');

    _t1ReportDate = DateTime.tryParse(
            pick('report_date', from: diagnoses)?.toString() ?? '') ??
        DateTime.now();
    _t1Dead = (pick('dead', from: diagnoses) as num?)?.toInt() ?? 0;
    _t1DeadSign = (pick('dead_sign', from: diagnoses) as List?) ?? [];
    _t1DeadSignOther = pick('dead_sign_other', from: diagnoses)?.toString();
    _t1Live = (pick('live', from: diagnoses) as num?)?.toInt() ?? 0;
    _t1LiveSign = (pick('live_sign', from: diagnoses) as List?) ?? [];
    _t1LiveSignOther = pick('live_sign_other', from: diagnoses)?.toString();
    _t1Chronological = pick('chronological', from: diagnoses)?.toString();
    _t1Sampling = pick('sampling', from: diagnoses)?.toString();
    _t1FollowUp = pick('follow_up', from: diagnoses)?.toString();
    _t1TemporaryDiagnosisId = pick('temporary_diagnosis_id', from: diagnoses);
    _t1Diagnosis = pick('diagnosis', from: diagnoses)?.toString() ??
        _currentReport['description']?.toString();

    final userFields = UserProfileFields(_currentUserRaw);
    _t1ReporterName = pick('name', from: reporter)?.toString() ?? userFields.name;
    _t1ReporterGender =
        pick('gender', from: reporter)?.toString() ?? userFields.gender;
    _t1ReporterOccupation =
        pick('occupation', from: reporter)?.toString() ?? userFields.role;
    _t1ReporterPhone = pick('phone', from: reporter)?.toString() ?? userFields.phone;
    _t1ReporterAddress = pick('address', from: reporter)?.toString() ??
        pick('address', from: upt)?.toString() ??
        userFields.address;
    _t1ReporterCaseFound = pick('case_found', from: reporter)?.toString();

    // UPT auto-fill precedence: existing report data first, then the
    // logged-in user's own UPT (revisi.md bug note #2) — never left blank
    // for a new report.
    _t1UptId = pick('upt_id', from: location) ??
        pick('upt_id', from: upt) ??
        userFields.uptId;
    _t1UptType = (pick('upt_type', from: location) ??
            pick('upt_type', from: upt) ??
            userFields.uptType)
        ?.toString();

    _t1LocationName = pick('location_name', from: location)?.toString();
    _t1LocationDescription =
        pick('location_description', from: location)?.toString();
    _t1ConservationType = pick('conservation_type', from: location)?.toString();
    _t1Insitu = (pick('insitu_conservation', from: location) as List?) ?? [];
    _t1InsituOther = pick('insitu_other', from: location)?.toString();
    _t1Exsitu = (pick('exsitu_conservation', from: location) as List?) ?? [];
    _t1ExsituOther = pick('exsitu_other', from: location)?.toString();
    final lat = pick('latitude', from: location) ?? pick('latitude', from: upt);
    final lng = pick('longitude', from: location) ?? pick('longitude', from: upt);
    _t1Latitude = lat is double ? lat : double.tryParse('$lat');
    _t1Longitude = lng is double ? lng : double.tryParse('$lng');
    _t1ProvinceId = pick('province_id', from: location);
    _t1DistrictId = pick('district_id', from: location);
    _t1SubdistrictId = pick('subdistrict_id', from: location);
    _t1VillageId = pick('village_id', from: location);
  }

  void _hydrateTab2() {
    final v = _section('verification');
    if (v == null) return;
    _t2VerifiedDate = DateTime.tryParse(v['verified_date']?.toString() ?? '');
    _t2Verified = v['verified'] == true;
    _t2Verification = v['verification']?.toString();
    _t2TemporaryDiseaseId = v['temporary_disease_id'];
    _t2Sampling = v['sampling']?.toString();
    _t2Action = v['action'];
    _t2DoctorInformation = v['doctor_information']?.toString();
    _t2InvolvedDoctors = ((v['involved_doctors'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _hydrateTab3() {
    final l = _section('lab');
    if (l == null) return;
    _t3FinalDiseaseId = l['final_disease_id'];
    _t3FinalDiagnosis = l['final_diagnosis']?.toString();
    _t3FollowUp = l['follow_up'];
  }

  void _hydrateTab4() {
    final i = _section('investigation');
    if (i == null) return;
    _t4DateFrom =
        DateTime.tryParse(i['investigation_date_from']?.toString() ?? '');
    _t4DateTo = DateTime.tryParse(i['investigation_date_to']?.toString() ?? '');
    _t4InspectionMethod = i['inspection_method']?.toString();
    _t4Evidence = ((i['evidence'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _t4FollowUpCarriedOut = i['follow_up_carried_out']?.toString();
    _t4AdditionalInformation = i['additional_information']?.toString();
    _t4DataInvestigation = ((i['data_investigation'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _fetchGps() async {
    setState(() => _t1FetchingGps = true);
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
        _t1Latitude = position.latitude;
        _t1Longitude = position.longitude;
      });
    } catch (_) {
      if (mounted) {
        showSnackbar(context, 'Tidak bisa mengambil lokasi GPS.');
      }
    } finally {
      if (mounted) setState(() => _t1FetchingGps = false);
    }
  }

  Future<List<String>> _encodePhotos(List<String> localPaths) async {
    final encoded = <String>[];
    for (final path in localPaths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      encoded.add('data:image/jpeg;base64,${base64Encode(bytes)}');
    }
    return encoded;
  }

  Future<void> _delete() async {
    final token = FFAppState().accessToken;
    if (token == null || _clientId == null) return;
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
    final success = await ReportRepository()
        .delete(_clientId!, token: token, serverId: _serverId);
    if (!mounted) return;
    setState(() => _isDeleting = false);
    if (success) {
      showSnackbar(context, 'Laporan dihapus.');
      context.pop();
    } else {
      showSnackbar(context, 'Gagal menghapus laporan.');
    }
  }

  void _goToList() {
    context.pushNamed(ReportHistoryWidget.routeName);
  }

  // ---- Tab 1 submit ----
  Future<void> _saveTab1() async {
    setState(() {
      _savingTab1 = true;
      _tab1Error = null;
    });
    final clientId = _clientId ??= ReportRepository().newClientId();
    final files = await _encodePhotos(_t1NewPhotoPaths);
    final user = _currentUserRaw ?? const <String, dynamic>{};
    final userId = user['id'];
    final reportDate =
        (_t1ReportDate ?? DateTime.now()).toIso8601String().split('T').first;
    // Must match the same dual-format check the UI uses to decide which
    // group to show (line ~1117/1132) — the real master `conservation_type`
    // option ids aren't confirmed numeric vs string-label yet (unverified
    // assumption), so both are accepted here too. Using only the string
    // label previously meant a numeric-id backend would silently drop
    // whatever the user picked in the In-situ/Ex-situ tag pickers on save.
    final isLkKhusus =
        _t1ConservationType == 'LK Khusus' || _t1ConservationType == '1';
    final isLkUmum =
        _t1ConservationType == 'LK Umum' || _t1ConservationType == '2';

    final payload = <String, dynamic>{
      // Omit `id` entirely on create — confirmed live 2026-08-12 that
      // sending `id: 0` (i.e. `_serverId` still null, no report on the
      // server yet) makes the backend respond `success: true, data: null`
      // instead of creating the record. Only include it once a real
      // `_serverId` exists (an update to an already-created report). See the
      // doc comment on `ApiEndpoints.generalReportsSave`.
      if (_serverId != null) 'id': _serverId,
      'creator': userId,
      'updater': userId,
      // Always false — the user has asked this app to never flag reports as
      // training data, regardless of the account's own `trained` flag.
      'training': false,
      'status': 1,
      'user_id': userId,
      'report_code': _reportCode ?? '',
      'report_date': reportDate,
      'location': _t1LocationName ?? '',
      'species_id': _t1ProtectedSpeciesId,
      'protected': _t1Protected,
      'protected_species': _t1Protected ? 1 : 0,
      'species_name': _t1SpeciesName ?? '',
      'dead': _t1Dead,
      'live': _t1Live,
      'description': _t1Diagnosis ?? '',
      'name': _t1ReporterName ?? '',
      'gender': _t1ReporterGender,
      'occupation': _t1ReporterOccupation ?? '',
      'phone': _t1ReporterPhone ?? '',
      'case_found': _t1ReporterCaseFound ?? '',
      'address': _t1ReporterAddress ?? '',
      'reporter_id': userId,
      'upt_id': _t1UptId,
      'upt_type': _t1UptType ?? '',
      'location_name': _t1LocationName ?? '',
      'conservation_type': _t1ConservationType ?? '',
      'insitu_conservation': isLkKhusus ? _t1Insitu : <dynamic>[],
      'insitu_other': isLkKhusus ? (_t1InsituOther ?? '') : '',
      'exsitu_conservation': isLkUmum ? _t1Exsitu : <dynamic>[],
      'exsitu_other': isLkUmum ? (_t1ExsituOther ?? '') : '',
      'province_id': _t1ProvinceId,
      'district_id': _t1DistrictId,
      'subdistrict_id': _t1SubdistrictId,
      'village_id': _t1VillageId,
      'location_description': _t1LocationDescription ?? '',
      'latitude': _t1Latitude?.toString() ?? '',
      'longitude': _t1Longitude?.toString() ?? '',
      'category': _t1Category,
      'species_latin_name': _t1SpeciesLatinName ?? '',
      'species_family': _t1SpeciesFamily ?? '',
      'species_age': _t1SpeciesAge ?? '',
      'population': _t1Population ?? 0,
      'dead_sign': _t1DeadSign,
      'dead_sign_other': _t1DeadSignOther ?? '',
      'live_sign': _t1LiveSign,
      'live_sign_other': _t1LiveSignOther ?? '',
      'chronological': _t1Chronological ?? '',
      'sampling': _t1Sampling ?? '',
      'follow_up': _t1FollowUp ?? '',
      'diagnosis': _t1Diagnosis ?? '',
      'temporary_diagnosis_id': _t1TemporaryDiagnosisId,
      if (files.isNotEmpty) 'file': files,
    };

    final result = await ReportRepository().submit(
      clientId: clientId,
      payload: payload,
      token: FFAppState().accessToken,
      endpoint: ApiEndpoints.generalReportsSave,
    );
    if (!mounted) return;
    setState(() => _savingTab1 = false);

    if (result.status == ReportSubmitStatus.failed) {
      setState(() => _tab1Error = result.message ?? 'Gagal menyimpan laporan.');
      return;
    }
    _localRowSeen = true;
    showSnackbar(
        context,
        result.status == ReportSubmitStatus.sentImmediately
            ? 'Laporan tersimpan.'
            : 'Tersimpan lokal — akan disinkron saat online.');
    _goToList();
  }

  Future<void> _submitSection({
    required String sectionKey,
    required Map<String, dynamic> sectionPayload,
    required String endpoint,
    required void Function(bool saving) setSaving,
    required void Function(String? error) setError,
  }) async {
    if (_clientId == null) return;
    setSaving(true);
    setError(null);
    final result = await ReportRepository().submitSection(
      clientId: _clientId!,
      sectionKey: sectionKey,
      sectionPayload: sectionPayload,
      endpoint: endpoint,
      token: FFAppState().accessToken,
    );
    if (!mounted) return;
    setSaving(false);
    if (result.status == ReportSubmitStatus.failed) {
      setError(result.message ?? 'Gagal menyimpan.');
      return;
    }
    showSnackbar(
        context,
        result.status == ReportSubmitStatus.sentImmediately
            ? 'Tersimpan.'
            : 'Tersimpan lokal — akan disinkron saat online.');
    _goToList();
  }

  Future<void> _saveTab2() async {
    final files = await _encodePhotos(_t2NewPhotoPaths);
    await _submitSection(
      sectionKey: 'verification',
      endpoint: ApiEndpoints.saveVerify,
      setSaving: (v) => setState(() => _savingTab2 = v),
      setError: (v) => setState(() => _tab2Error = v),
      sectionPayload: {
        'verified_date': (_t2VerifiedDate ?? DateTime.now())
            .toIso8601String()
            .split('T')
            .first,
        'verified': _t2Verified,
        'verification': _t2Verification ?? '',
        'temporary_disease_id': _t2TemporaryDiseaseId,
        'sampling': _t2Sampling ?? '',
        'action': _t2Action,
        'doctor_information': _t2DoctorInformation ?? '',
        'involved_doctors': _t2InvolvedDoctors,
        if (files.isNotEmpty) 'file_verification': files,
      },
    );
  }

  Future<void> _saveTab3() async {
    await _submitSection(
      sectionKey: 'lab',
      endpoint: ApiEndpoints.saveLab,
      setSaving: (v) => setState(() => _savingTab3 = v),
      setError: (v) => setState(() => _tab3Error = v),
      sectionPayload: {
        'final_disease_id': _t3FinalDiseaseId,
        'final_diagnosis': _t3FinalDiagnosis ?? '',
        'follow_up': _t3FollowUp,
      },
    );
  }

  Future<void> _saveTab4() async {
    final files = await _encodePhotos(_t4NewPhotoPaths);
    final now = DateTime.now();
    await _submitSection(
      sectionKey: 'investigation',
      endpoint: ApiEndpoints.saveInvestigation,
      setSaving: (v) => setState(() => _savingTab4 = v),
      setError: (v) => setState(() => _tab4Error = v),
      sectionPayload: {
        'investigation_date_from':
            (_t4DateFrom ?? now).toIso8601String().split('T').first,
        'investigation_date_to':
            (_t4DateTo ?? now).toIso8601String().split('T').first,
        'inspection_method': _t4InspectionMethod ?? '',
        'evidence': _t4Evidence,
        'follow_up_carried_out': _t4FollowUpCarriedOut ?? '',
        'additional_information': _t4AdditionalInformation ?? '',
        'data_investigation': _t4DataInvestigation,
        if (files.isNotEmpty) 'file_investigation': files,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = _isDoctor;
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
                padding: EdgeInsetsDirectional.fromSTEB(8.0, 22.0, 20.0, 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          FlutterFlowIconButton(
                            borderRadius: 8.0,
                            buttonSize: 40.0,
                            icon: Icon(LucideIcons.arrowLeft,
                                color: FlutterFlowTheme.of(context).primaryText),
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Text(
                              _reportCode != null && _reportCode!.isNotEmpty
                                  ? 'KODE LAPORAN: $_reportCode'
                                  : 'Menunggu sinkronisasi',
                              overflow: TextOverflow.ellipsis,
                              style: FlutterFlowTheme.of(context).titleLarge.override(
                                    font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold),
                                    color: FlutterFlowTheme.of(context).primaryText,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_clientId != null)
                      FlutterFlowIconButton(
                        borderRadius: 8.0,
                        buttonSize: 40.0,
                        icon: Icon(LucideIcons.trash2,
                            color: FlutterFlowTheme.of(context).error),
                        onPressed: _isDeleting ? null : _delete,
                      ),
                  ],
                ),
              ),
            ),
          ),
          TrainingModeBanner(),
          if (showTabs)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: FlutterFlowTheme.of(context).primary,
              unselectedLabelColor: FlutterFlowTheme.of(context).secondaryText,
              indicatorColor: FlutterFlowTheme.of(context).primary,
              tabs: [
                Tab(text: 'Investigasi'),
                Tab(text: 'Verifikasi Dokter Hewan'),
                Tab(text: 'Konfirmasi Hasil Lab'),
                Tab(text: 'Investigasi Lanjutan'),
              ],
            ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _loadError != null && _currentReport.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(_loadError!,
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium),
                        ),
                      )
                    : showTabs
                        ? TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTab1(context),
                              _hasLocalRow
                                  ? _buildTab2(context)
                                  : _buildTabBlocked(context),
                              _hasLocalRow
                                  ? _buildTab3(context)
                                  : _buildTabBlocked(context),
                              _hasLocalRow
                                  ? _buildTab4(context)
                                  : _buildTabBlocked(context),
                            ],
                          )
                        : _buildTab1(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBlocked(BuildContext context) => Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Simpan tab Investigasi terlebih dahulu.',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium),
        ),
      );

  // ---------------------------------------------------------------------
  // Tab 1 — Investigasi
  // ---------------------------------------------------------------------
  Widget _buildTab1(BuildContext context) {
    final steps = <Widget>[
      _buildStepSpecies(context),
      _buildStepInvestigasi(context),
      _buildStepLokasi(context),
      _buildStepPelapor(context),
    ];
    final isLastStep = _t1Step == steps.length - 1;
    return Column(
      children: [
        _t1StepIndicator(context),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                steps[_t1Step],
                if (isLastStep && _tab1Error != null) ...[
                  SizedBox(height: 12.0),
                  Text(_tab1Error!,
                      style: FlutterFlowTheme.of(context)
                          .bodySmall
                          .override(color: FlutterFlowTheme.of(context).error)),
                ],
              ],
            ),
          ),
        ),
        _t1StepNavBar(context, isLastStep),
      ],
    );
  }

  /// Tappable step circles + connecting lines + current step's title —
  /// tapping a circle jumps straight to that step (no per-step validation
  /// gate, matches this form's existing no-required-fields behavior).
  Widget _t1StepIndicator(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(24.0, 16.0, 24.0, 12.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(bottom: BorderSide(color: theme.alternate)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < _t1StepTitles.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2.0,
                      color: i <= _t1Step ? theme.primary : theme.alternate,
                    ),
                  ),
                InkWell(
                  onTap: () => setState(() => _t1Step = i),
                  borderRadius: BorderRadius.circular(14.0),
                  child: CircleAvatar(
                    radius: 14.0,
                    backgroundColor:
                        i <= _t1Step ? theme.primary : theme.alternate,
                    child: i < _t1Step
                        ? Icon(LucideIcons.check, size: 16.0, color: theme.onPrimary)
                        : Text('${i + 1}',
                            style: theme.labelMedium.override(
                              color: i == _t1Step
                                  ? theme.onPrimary
                                  : theme.secondaryText,
                              fontWeight: FontWeight.bold,
                            )),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.0),
          Text(
            'Langkah ${_t1Step + 1} dari ${_t1StepTitles.length}: '
            '${_t1StepTitles[_t1Step]}',
            style: theme.titleSmall.override(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// "Kembali" (hidden on the first step) + "Lanjut", swapping to the real
  /// "Simpan Investigasi" save button once on the last step.
  Widget _t1StepNavBar(BuildContext context, bool isLastStep) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(top: BorderSide(color: theme.alternate)),
      ),
      child: Row(
        children: [
          if (_t1Step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _t1Step--),
                child: Text('Kembali'),
              ),
            ),
            SizedBox(width: 12.0),
          ],
          Expanded(
            flex: 2,
            child: isLastStep
                ? _saveButton(
                    label: 'Simpan Investigasi',
                    isSaving: _savingTab1,
                    onTap: _saveTab1,
                  )
                : ElevatedButton(
                    onPressed: () => setState(() => _t1Step++),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: theme.onPrimary,
                      padding: EdgeInsets.symmetric(vertical: 14.0),
                    ),
                    child: Text('Lanjut'),
                  ),
          ),
        ],
      ),
    );
  }

  // ---- Step 1: Data Species ----
  Widget _buildStepSpecies(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          _switchField(
            label: 'Satwa Dilindungi?',
            value: _t1Protected,
            onChanged: (v) => setState(() {
              _t1Protected = v;
              if (!v) _t1ProtectedSpeciesId = null;
            }),
          ),
          if (_t1Protected)
            SearchSelectWidget(
              label: 'Satwa Dilindungi',
              hint: 'Cari nama satwa dilindungi...',
              options: _protectedSpecies,
              selectedId: _t1ProtectedSpeciesId,
              selectedLabel: _t1SpeciesName,
              optionLabel: optionLabel,
              optionId: optionId,
              onSelected: (selected) => setState(() {
                _t1ProtectedSpeciesId = optionId(selected);
                _t1SpeciesName = optionLabel(selected);
                _t1SpeciesLatinName = (selected['latin_name'] ?? '').toString();
                final category = selected['category'];
                if (category != null) _t1Category = category.toString();
                // Species master has no dedicated "family" field, but its
                // broader `type` (e.g. "MAMALIA (MENYUSUI)") is the same
                // classification the Famili dropdown's `animal_types`
                // master group uses as option labels — match by label to
                // find the matching option id so the dropdown auto-selects.
                final type = selected['type']?.toString();
                if (type != null && type.isNotEmpty) {
                  final match = _animalTypes.firstWhere(
                    (o) => optionLabel(o) == type,
                    orElse: () => const {},
                  );
                  if (match.isNotEmpty) {
                    _t1SpeciesFamily = optionId(match)?.toString();
                  }
                }
              }),
            )
          else ...[
            _dropdown(
              label: 'Kategori',
              value: _t1Category,
              options: _speciesCategories,
              onChanged: (v) => setState(() => _t1Category = v?.toString()),
            ),
            _textField(
              label: 'Nama Spesies',
              value: _t1SpeciesName,
              onChanged: (v) => _t1SpeciesName = v,
            ),
          ],
          _textField(
            label: 'Nama Latin',
            value: _t1SpeciesLatinName,
            onChanged: (v) => _t1SpeciesLatinName = v,
          ),
          _dropdown(
            label: 'Famili',
            value: _t1SpeciesFamily,
            options: _animalTypes,
            onChanged: (v) => setState(() => _t1SpeciesFamily = v?.toString()),
          ),
          _dropdown(
            label: 'Usia',
            value: _t1SpeciesAge,
            options: _ageGroups,
            onChanged: (v) => setState(() => _t1SpeciesAge = v?.toString()),
          ),
          _textField(
            label: 'Populasi',
            value: _t1Population?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (v) => _t1Population = int.tryParse(v),
          ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  // ---- Step 2: Tahap Investigasi ----
  Widget _buildStepInvestigasi(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          DateFieldWidget(
            label: 'Tanggal Laporan',
            date: _t1ReportDate,
            lastDate: DateTime.now(),
            onChanged: (v) => setState(() => _t1ReportDate = v),
          ),
          Row(
            children: [
              Expanded(
                child: _textField(
                  label: 'Jumlah Mati',
                  value: _t1Dead.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _t1Dead = int.tryParse(v) ?? 0),
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: _textField(
                  label: 'Jumlah Hidup',
                  value: _t1Live.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      setState(() => _t1Live = int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          if (_t1Live > 0) ...[
            TagMultiSelectWidget(
              label: 'Tanda Kehidupan',
              options: _liveSignOptions,
              selectedIds: _t1LiveSign,
              optionLabel: optionLabel,
              optionId: optionId,
              onChanged: (v) => setState(() => _t1LiveSign = v),
            ),
            _textField(
              label: 'Tanda Kehidupan Lainnya',
              value: _t1LiveSignOther,
              onChanged: (v) => _t1LiveSignOther = v,
            ),
          ],
          if (_t1Dead > 0) ...[
            TagMultiSelectWidget(
              label: 'Tanda Kematian',
              options: _deadSignOptions,
              selectedIds: _t1DeadSign,
              optionLabel: optionLabel,
              optionId: optionId,
              onChanged: (v) => setState(() => _t1DeadSign = v),
            ),
            _textField(
              label: 'Tanda Kematian Lainnya',
              value: _t1DeadSignOther,
              onChanged: (v) => _t1DeadSignOther = v,
            ),
          ],
          _textField(
            label: 'Kronologis',
            value: _t1Chronological,
            onChanged: (v) => _t1Chronological = v,
          ),
          _textField(
            label: 'Sampling',
            value: _t1Sampling,
            onChanged: (v) => _t1Sampling = v,
          ),
          // `follow_up` is a free-text column on the backend (confirmed
          // against the live web app: the master `follow_ups` list there is
          // just tap-to-insert suggestion chips above a plain textarea, not
          // an enum/FK) — must NOT be a master-data-id dropdown here.
          _textField(
            label: 'Tindak Lanjut',
            value: _t1FollowUp,
            onChanged: (v) => _t1FollowUp = v,
          ),
          _dropdown(
            label: 'Kesimpulan Awal',
            value: _t1TemporaryDiagnosisId,
            options: _temporaryDiagnosisOptions,
            onChanged: (v) =>
                setState(() => _t1TemporaryDiagnosisId = v),
          ),
          _textField(
            label: 'Diagnosis',
            value: _t1Diagnosis,
            onChanged: (v) => _t1Diagnosis = v,
          ),
          MultiImagePickerWidget(
            label: 'Foto Bukti',
            existingMediaUrls:
                _mediaItems().map(_mediaUrl).whereType<String>().toList(),
            newLocalPaths: _t1NewPhotoPaths,
            onLocalPathsChanged: (v) => setState(() => _t1NewPhotoPaths = v),
          ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  // ---- Step 3: Data Administrasi — Lokasi ----
  Widget _buildStepLokasi(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          SimpleDropdownWidget(
            label: 'Tipe UPT',
            value: _t1UptType,
            options: _uptTypes,
            optionLabel: optionLabel,
            optionId: optionId,
            onChanged: null,
            enabled: false,
          ),
          SimpleDropdownWidget(
            label: 'Nama UPT',
            value: _t1UptId,
            options: _upts
                .where((u) =>
                    _t1UptType == null || u['type']?.toString() == _t1UptType)
                .toList(),
            optionLabel: optionLabel,
            optionId: optionId,
            onChanged: null,
            enabled: false,
          ),
          _textField(
            label: 'Nama Lokasi',
            value: _t1LocationName,
            onChanged: (v) => _t1LocationName = v,
          ),
          _dropdown(
            label: 'Tipe Konservasi',
            value: _t1ConservationType,
            options: _conservationTypes,
            onChanged: (v) => setState(() => _t1ConservationType = v?.toString()),
          ),
          if (_t1ConservationType == 'LK Khusus' || _t1ConservationType == '1') ...[
            // Single-choice: picking a tag clears any typed "Lainnya" text
            // and vice versa, so the two never disagree about which one
            // choice is actually selected.
            TagMultiSelectWidget(
              label: 'Konservasi In-situ',
              options: _insituOptions,
              selectedIds: _t1Insitu,
              optionLabel: optionLabel,
              optionId: optionId,
              singleSelect: true,
              onChanged: (v) => setState(() {
                _t1Insitu = v;
                if (v.isNotEmpty) _t1InsituOther = '';
              }),
            ),
            _textField(
              label: 'In-situ Lainnya',
              value: _t1InsituOther,
              onChanged: (v) => setState(() {
                _t1InsituOther = v;
                if (v.isNotEmpty) _t1Insitu = [];
              }),
            ),
          ],
          if (_t1ConservationType == 'LK Umum' || _t1ConservationType == '2') ...[
            TagMultiSelectWidget(
              label: 'Konservasi Ex-situ',
              options: _exsituOptions,
              selectedIds: _t1Exsitu,
              optionLabel: optionLabel,
              optionId: optionId,
              singleSelect: true,
              onChanged: (v) => setState(() {
                _t1Exsitu = v;
                if (v.isNotEmpty) _t1ExsituOther = '';
              }),
            ),
            _textField(
              label: 'Ex-situ Lainnya',
              value: _t1ExsituOther,
              onChanged: (v) => setState(() {
                _t1ExsituOther = v;
                if (v.isNotEmpty) _t1Exsitu = [];
              }),
            ),
          ],
          _dropdown(
            label: 'Provinsi',
            value: _t1ProvinceId,
            options: _provinces,
            onChanged: (v) => setState(() {
              _t1ProvinceId = v;
              _t1DistrictId = null;
              _t1SubdistrictId = null;
              _t1VillageId = null;
            }),
          ),
          _dropdown(
            label: 'Kabupaten/Kota',
            value: _t1DistrictId,
            options:
                _childrenOf(_districts, _t1ProvinceId, ['province_id', 'provinceId']),
            onChanged: (v) => setState(() {
              _t1DistrictId = v;
              _t1SubdistrictId = null;
              _t1VillageId = null;
            }),
          ),
          _dropdown(
            label: 'Kecamatan',
            value: _t1SubdistrictId,
            options:
                _childrenOf(_subdistricts, _t1DistrictId, ['district_id', 'districtId']),
            onChanged: (v) => setState(() {
              _t1SubdistrictId = v;
              _t1VillageId = null;
            }),
          ),
          _dropdown(
            label: 'Desa/Kelurahan',
            value: _t1VillageId,
            options: _childrenOf(
                _villages, _t1SubdistrictId, ['subdistrict_id', 'subdistrictId']),
            onChanged: (v) => setState(() => _t1VillageId = v),
          ),
          _textField(
            label: 'Deskripsi Lokasi',
            value: _t1LocationDescription,
            onChanged: (v) => _t1LocationDescription = v,
          ),
          Row(
            children: [
              Expanded(
                child: _readonlyField(
                    label: 'Latitude',
                    value: _t1Latitude?.toStringAsFixed(6)),
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: _readonlyField(
                    label: 'Longitude',
                    value: _t1Longitude?.toStringAsFixed(6)),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _t1FetchingGps ? null : _fetchGps,
            icon: _t1FetchingGps
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(LucideIcons.refreshCw, size: 16.0),
            label: Text('Perbarui Lokasi GPS'),
          ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  // ---- Step 4: Data Administrasi — Pelapor ----
  Widget _buildStepPelapor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          _textField(
            label: 'Nama Pelapor',
            value: _t1ReporterName,
            onChanged: (v) => _t1ReporterName = v,
          ),
          _dropdown(
            label: 'Jenis Kelamin',
            value: _t1ReporterGender,
            options: _genders,
            onChanged: (v) => setState(() => _t1ReporterGender = v?.toString()),
          ),
          _textField(
            label: 'Pekerjaan',
            value: _t1ReporterOccupation,
            onChanged: (v) => _t1ReporterOccupation = v,
          ),
          _textField(
            label: 'No. HP',
            value: _t1ReporterPhone,
            onChanged: (v) => _t1ReporterPhone = v,
          ),
          _textField(
            label: 'Alamat',
            value: _t1ReporterAddress,
            onChanged: (v) => _t1ReporterAddress = v,
          ),
      ].divide(SizedBox(height: 16.0)),
    );
  }

  // ---------------------------------------------------------------------
  // Tab 2 — Verifikasi Dokter Hewan
  // ---------------------------------------------------------------------
  Widget _buildTab2(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateFieldWidget(
            label: 'Tanggal Verifikasi',
            date: _t2VerifiedDate,
            onChanged: (v) => setState(() => _t2VerifiedDate = v),
          ),
          TextFieldWidget(
            label: 'Catatan Verifikasi',
            hint: 'Hasil pemeriksaan',
            value: _t2Verification ?? '',
            onChanged: (v) => _t2Verification = v,
            variant: 'outlined',
          ),
          _switchField(
            label: 'Suspek Penyakit?',
            value: _t2Verified,
            onChanged: (v) => setState(() => _t2Verified = v),
          ),
          if (_t2Verified)
            _dropdown(
              label: 'Diagnosis Sementara',
              value: _t2TemporaryDiseaseId,
              options: _diseases,
              onChanged: (v) => setState(() => _t2TemporaryDiseaseId = v),
            ),
          TextFieldWidget(
            label: 'Sampling',
            hint: 'Sampel yang diambil',
            value: _t2Sampling ?? '',
            onChanged: (v) => _t2Sampling = v,
            variant: 'outlined',
          ),
          // `action` is a free-text column on the backend (same tap-to-insert
          // suggestion-chips-over-a-textarea pattern as Tab 1's `follow_up`),
          // not a master-data-id dropdown.
          _textField(
            label: 'Tindakan',
            value: _t2Action?.toString(),
            onChanged: (v) => _t2Action = v,
          ),
          TextFieldWidget(
            label: 'Informasi Dokter',
            hint: 'Catatan dokter pemeriksa',
            value: _t2DoctorInformation ?? '',
            onChanged: (v) => _t2DoctorInformation = v,
            variant: 'outlined',
          ),
          Text('Dokter Terlibat',
              style: FlutterFlowTheme.of(context)
                  .labelMedium
                  .override(fontWeight: FontWeight.w600)),
          RepeaterListWidget<Map<String, dynamic>>(
            items: _t2InvolvedDoctors,
            addLabel: 'Tambah Dokter',
            onAdd: () => setState(() => _t2InvolvedDoctors = [
                  ..._t2InvolvedDoctors,
                  {'name': '', 'occupation': '', 'date': '', 'sign': false},
                ]),
            onRemove: (i) => setState(() {
              final next = List<Map<String, dynamic>>.from(_t2InvolvedDoctors);
              next.removeAt(i);
              _t2InvolvedDoctors = next;
            }),
            rowBuilder: (context, i, item) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _textField(
                  label: 'Nama',
                  value: item['name']?.toString(),
                  onChanged: (v) => item['name'] = v,
                ),
                _textField(
                  label: 'Jabatan',
                  value: item['occupation']?.toString(),
                  onChanged: (v) => item['occupation'] = v,
                ),
                _textField(
                  label: 'Tanggal',
                  value: item['date']?.toString(),
                  onChanged: (v) => item['date'] = v,
                ),
                _switchField(
                  label: 'Tanda Tangan',
                  value: item['sign'] == true,
                  onChanged: (v) => setState(() => item['sign'] = v),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
          ),
          MultiImagePickerWidget(
            label: 'Foto Verifikasi',
            existingMediaUrls: const [],
            newLocalPaths: _t2NewPhotoPaths,
            onLocalPathsChanged: (v) => setState(() => _t2NewPhotoPaths = v),
          ),
          if (_tab2Error != null)
            Text(_tab2Error!,
                style: FlutterFlowTheme.of(context)
                    .bodySmall
                    .override(color: FlutterFlowTheme.of(context).error)),
          _saveButton(
              label: 'Simpan Verifikasi', isSaving: _savingTab2, onTap: _saveTab2),
        ].divide(SizedBox(height: 16.0)),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Tab 3 — Konfirmasi Dari Hasil Lab
  // ---------------------------------------------------------------------
  Widget _buildTab3(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dropdown(
            label: 'Diagnosis Akhir',
            value: _t3FinalDiseaseId,
            options: _diseases,
            onChanged: (v) => setState(() => _t3FinalDiseaseId = v),
          ),
          TextFieldWidget(
            label: 'Catatan Diagnosis Akhir',
            hint: 'Detail hasil lab',
            value: _t3FinalDiagnosis ?? '',
            onChanged: (v) => _t3FinalDiagnosis = v,
            variant: 'outlined',
          ),
          // Same as Tab 1/Tab 2 — `follow_up` here ("Aksi Lanjutan" on the
          // web) is a free-text column, not a master-data-id dropdown.
          _textField(
            label: 'Tindak Lanjut',
            value: _t3FollowUp?.toString(),
            onChanged: (v) => _t3FollowUp = v,
          ),
          if (_tab3Error != null)
            Text(_tab3Error!,
                style: FlutterFlowTheme.of(context)
                    .bodySmall
                    .override(color: FlutterFlowTheme.of(context).error)),
          _saveButton(
              label: 'Simpan Hasil Lab', isSaving: _savingTab3, onTap: _saveTab3),
        ].divide(SizedBox(height: 16.0)),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Tab 4 — Investigasi Lanjutan
  // ---------------------------------------------------------------------
  Widget _buildTab4(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DateFieldWidget(
                  label: 'Tanggal Mulai',
                  date: _t4DateFrom,
                  onChanged: (v) => setState(() => _t4DateFrom = v),
                ),
              ),
              SizedBox(width: 12.0),
              Expanded(
                child: DateFieldWidget(
                  label: 'Tanggal Selesai',
                  date: _t4DateTo,
                  onChanged: (v) => setState(() => _t4DateTo = v),
                ),
              ),
            ],
          ),
          TextFieldWidget(
            label: 'Metode Pemeriksaan',
            hint: 'mis. Nekropsi lapangan',
            value: _t4InspectionMethod ?? '',
            onChanged: (v) => _t4InspectionMethod = v,
            variant: 'outlined',
          ),
          Text('Bukti',
              style: FlutterFlowTheme.of(context)
                  .labelMedium
                  .override(fontWeight: FontWeight.w600)),
          RepeaterListWidget<Map<String, dynamic>>(
            items: _t4Evidence,
            addLabel: 'Tambah Bukti',
            onAdd: () => setState(() => _t4Evidence = [
                  ..._t4Evidence,
                  {'type_of_evidence': '', 'amount': '', 'description': ''},
                ]),
            onRemove: (i) => setState(() {
              final next = List<Map<String, dynamic>>.from(_t4Evidence);
              next.removeAt(i);
              _t4Evidence = next;
            }),
            rowBuilder: (context, i, item) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _textField(
                  label: 'Jenis Bukti',
                  value: item['type_of_evidence']?.toString(),
                  onChanged: (v) => item['type_of_evidence'] = v,
                ),
                _textField(
                  label: 'Jumlah',
                  value: item['amount']?.toString(),
                  onChanged: (v) => item['amount'] = v,
                ),
                _textField(
                  label: 'Deskripsi',
                  value: item['description']?.toString(),
                  onChanged: (v) => item['description'] = v,
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
          ),
          MultiImagePickerWidget(
            label: 'Foto Investigasi',
            existingMediaUrls: const [],
            newLocalPaths: _t4NewPhotoPaths,
            onLocalPathsChanged: (v) => setState(() => _t4NewPhotoPaths = v),
          ),
          TextFieldWidget(
            label: 'Tindak Lanjut yang Dilakukan',
            hint: 'Ringkasan tindak lanjut',
            value: _t4FollowUpCarriedOut ?? '',
            onChanged: (v) => _t4FollowUpCarriedOut = v,
            variant: 'outlined',
          ),
          TextFieldWidget(
            label: 'Informasi Tambahan',
            hint: 'Catatan tambahan',
            value: _t4AdditionalInformation ?? '',
            onChanged: (v) => _t4AdditionalInformation = v,
            variant: 'outlined',
          ),
          Text('Data Investigasi',
              style: FlutterFlowTheme.of(context)
                  .labelMedium
                  .override(fontWeight: FontWeight.w600)),
          RepeaterListWidget<Map<String, dynamic>>(
            items: _t4DataInvestigation,
            addLabel: 'Tambah Data',
            onAdd: () => setState(() => _t4DataInvestigation = [
                  ..._t4DataInvestigation,
                  {'date': '', 'name': '', 'occupation': '', 'sign': false},
                ]),
            onRemove: (i) => setState(() {
              final next =
                  List<Map<String, dynamic>>.from(_t4DataInvestigation);
              next.removeAt(i);
              _t4DataInvestigation = next;
            }),
            rowBuilder: (context, i, item) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _textField(
                  label: 'Tanggal',
                  value: item['date']?.toString(),
                  onChanged: (v) => item['date'] = v,
                ),
                _textField(
                  label: 'Nama',
                  value: item['name']?.toString(),
                  onChanged: (v) => item['name'] = v,
                ),
                _textField(
                  label: 'Jabatan',
                  value: item['occupation']?.toString(),
                  onChanged: (v) => item['occupation'] = v,
                ),
                _switchField(
                  label: 'Tanda Tangan',
                  value: item['sign'] == true,
                  onChanged: (v) => setState(() => item['sign'] = v),
                ),
              ].divide(SizedBox(height: 8.0)),
            ),
          ),
          if (_tab4Error != null)
            Text(_tab4Error!,
                style: FlutterFlowTheme.of(context)
                    .bodySmall
                    .override(color: FlutterFlowTheme.of(context).error)),
          _saveButton(
              label: 'Simpan Investigasi Lanjutan',
              isSaving: _savingTab4,
              onTap: _saveTab4),
        ].divide(SizedBox(height: 16.0)),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Shared small helpers
  // ---------------------------------------------------------------------
  Widget _dropdown({
    required String label,
    required dynamic value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<dynamic>? onChanged,
    bool enabled = true,
  }) {
    return SimpleDropdownWidget(
      label: label,
      value: value,
      options: options,
      optionLabel: optionLabel,
      optionId: optionId,
      onChanged: onChanged,
      enabled: enabled,
    );
  }

  Widget _textField({
    required String label,
    String? value,
    TextInputType? keyboardType,
    required ValueChanged<String> onChanged,
  }) {
    return TextFieldWidget(
      label: label,
      hint: label,
      value: value ?? '',
      keyboardType: keyboardType,
      onChanged: onChanged,
      variant: 'outlined',
    );
  }

  Widget _readonlyField({required String label, String? value}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: FlutterFlowTheme.of(context).alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: FlutterFlowTheme.of(context).secondaryText)),
          Text(value ?? '-', style: FlutterFlowTheme.of(context).bodyMedium),
        ],
      ),
    );
  }

  Widget _switchField({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
            child:
                Text(label, style: FlutterFlowTheme.of(context).bodyMedium)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: FlutterFlowTheme.of(context).primary,
        ),
      ],
    );
  }

  Widget _saveButton({
    required String label,
    required bool isSaving,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isSaving ? null : onTap,
      child: Container(
        height: 48.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primary,
          borderRadius: BorderRadius.circular(10.0),
        ),
        alignment: Alignment.center,
        child: isSaving
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: FlutterFlowTheme.of(context).onPrimary),
              )
            : Text(label,
                style: FlutterFlowTheme.of(context).labelLarge.override(
                    color: FlutterFlowTheme.of(context).onPrimary,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }
}
