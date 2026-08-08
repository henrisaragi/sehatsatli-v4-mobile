import 'dart:convert';
import 'dart:io';

import '/components/photo_slot/photo_slot_widget.dart';
import '/components/step_indicator/step_indicator_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../data/models/user_profile_fields.dart';
import '../../data/repositories/report_repository.dart';
import 'new_general_report_widget.dart' show NewGeneralReportWidget;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class NewGeneralReportModel extends FlutterFlowModel<NewGeneralReportWidget> {
  ///  Wizard state.
  late String clientId;
  int currentStep = 0;
  static const int totalSteps = 4;
  bool isSubmitting = false;
  bool isFetchingGps = false;
  String? error;

  ///  Step 1 — Pelapor (reporter.*)
  String? reporterName;
  String? reporterGender;
  String? reporterOccupation;
  String? reporterPhone;
  String? reporterAddress;
  bool reporterCaseFound = false;

  ///  Step 2 — Lokasi (locations.*)
  dynamic locUptId;
  String? locUptType;
  /// Display name of the selected UPT (`upts/getAll`'s `name`), captured
  /// alongside `locUptId` purely for the flat `upt_name` payload field —
  /// docs/general-report-field.md.
  String? locUptName;
  String? locLocationName;
  String? locConservationType;
  List<String> locInsituConservation = [];
  String? locInsituOther;
  List<String> locExsituConservation = [];
  dynamic locProvinceId;
  dynamic locDistrictId;
  dynamic locSubdistrictId;
  dynamic locVillageId;
  String? locLocationDescription;
  double? locLatitude;
  double? locLongitude;

  ///  Step 3 — Spesies (species.*)
  String? specCategory;
  bool specProtected = false;
  /// `id` of the entry picked from the cached protected-species dropdown
  /// (null when the officer is typing the species manually instead).
  dynamic specSelectedId;
  String? specName;
  String? specLatinName;
  String? specFamily;
  String? specAge;
  int? specPopulation;

  ///  Step 4 — Diagnosis Awal (diagnoses.*)
  DateTime? diagReportDate;
  int diagDead = 0;
  List<String> diagDeadSign = [];
  String? diagDeadSignOther;
  int diagLive = 0;
  List<String> diagLiveSign = [];
  String? diagLiveSignOther;
  String? diagChronological;
  String? diagSampling;
  String? diagFollowUp;
  String? diagDiagnosis;
  dynamic diagTemporaryDiagnosisId;

  ///  Photo evidence — local file paths for the 3 slots (Subject/
  ///  Environment/Detail), populated by image_picker + flutter_image_compress
  ///  at capture time; base64-encoded lazily, only right before submit.
  List<String?> photoPaths = [null, null, null];

  ///  State fields for stateful widgets in this page.
  late StepIndicatorModel stepIndicatorModel;

  /// Raw `FFAppState().currentUser` snapshot, kept alongside the
  /// display-formatted [UserProfileFields] getters below — `toPayload()`
  /// needs the literal server values (`id`, `trained`, `gender` as
  /// `"1"`/`"2"`) for the `creator`/`updater`/`user_id`/`reporter_id`/
  /// `training`/`gender` fields per docs/general-report-field.md, not the
  /// human-readable versions used for the read-only Step 1 display.
  Map<String, dynamic>? currentUserRaw;

  @override
  void initState(BuildContext context) {
    clientId = ReportRepository().newClientId();
    diagReportDate = DateTime.now();
    stepIndicatorModel = createModel(context, () => StepIndicatorModel());

    // Step 1 (Pelapor) is identity data of the logged-in officer, not
    // something re-typed per report — pre-fill from the /auth/login-app
    // user snapshot instead of leaving it blank for manual entry.
    final currentUser = FFAppState().currentUser;
    currentUserRaw =
        currentUser is Map ? Map<String, dynamic>.from(currentUser) : null;
    final fields = UserProfileFields(currentUserRaw);
    reporterName = fields.name;
    reporterGender = fields.gender;
    reporterOccupation = fields.role;
    reporterPhone = fields.phone;
    reporterAddress = fields.address;
  }

  @override
  void dispose() {
    stepIndicatorModel.dispose();
  }

  static bool _truthy(dynamic v) => v == true || v == 1 || v == '1';

  /// Builds the flat payload for `POST /api/general-reports/save` per
  /// docs/general-report-field.md — a different, newer endpoint from the
  /// nested `saveGeneralReportMobile` shape the Step-5 edit forms
  /// (verification/lab/investigation) still use via
  /// `ReportRepository.mergeSection`. `id: 0` marks this as always a new
  /// report — this wizard has no "edit an existing report" mode.
  Map<String, dynamic> toPayload() {
    final reportDate =
        (diagReportDate ?? DateTime.now()).toIso8601String().split('T').first;
    final user = currentUserRaw ?? const <String, dynamic>{};
    final userId = user['id'];
    final isLkKhusus = locConservationType == 'LK Khusus';
    final isLkUmum = locConservationType == 'LK Umum';
    final isLainnya = locConservationType == 'Lainnya';
    return {
      'id': 0,
      'creator': userId,
      'updater': userId,
      'training': _truthy(user['trained']),
      'status': 1,
      'user_id': userId,
      'report_code': '',
      'report_date': reportDate,
      // No separate free-text field exists for this in the UI — `location`
      // and `location_name` look like the same concept in the doc's flat
      // payload, so mirror `location_name` here until confirmed otherwise.
      'location': locLocationName ?? '',
      'species_id': specSelectedId,
      'protected': specProtected,
      'protected_species': specProtected ? 1 : 0,
      'species_name': specName ?? '',
      'dead': diagDead,
      'live': diagLive,
      'description': diagDiagnosis ?? '',
      'client_id': null, // set by ReportRepository.submit/saveDraft
      'name': reporterName ?? '',
      'gender': user['gender'],
      'occupation': reporterOccupation ?? '',
      'phone': reporterPhone ?? '',
      'address': reporterAddress ?? '',
      'case_found': reporterCaseFound,
      'reporter_id': userId,
      'upt_id': locUptId,
      'upt_type': locUptType ?? '',
      'upt_name': locUptName ?? '',
      'location_name': locLocationName ?? '',
      'conservation_type': locConservationType ?? '',
      'insitu_conservation': isLkKhusus ? locInsituConservation : <String>[],
      'insitu_other': isLainnya ? (locInsituOther ?? '') : '',
      'exsitu_conservation': isLkUmum ? locExsituConservation : <String>[],
      // Deliberately always null per docs/general-report-field.md — no text
      // field is built for this.
      'exsitu_other': null,
      'province_id': locProvinceId,
      'district_id': locDistrictId,
      'subdistrict_id': locSubdistrictId,
      'village_id': locVillageId,
      'location_description': locLocationDescription ?? '',
      'latitude': locLatitude?.toString() ?? '',
      'longitude': locLongitude?.toString() ?? '',
      // Deliberately null per docs/general-report-field.md ("null tidak
      // perlu teksfield") — the Kategori dropdown still exists in the UI for
      // auto-filling species fields, but its value isn't part of this
      // payload.
      'category': null,
      'species_latin_name': specLatinName ?? '',
      'species_family': specFamily ?? '',
      'species_age': specAge ?? '',
      'population': specPopulation ?? 0,
      'dead_sign': diagDeadSign,
      'dead_sign_other': diagDeadSignOther ?? '',
      'live_sign': diagLiveSign,
      'live_sign_other': diagLiveSignOther ?? '',
      'chronological': diagChronological ?? '',
      'sampling': diagSampling ?? '',
      'follow_up': diagFollowUp ?? '',
      'diagnosis': diagDiagnosis ?? '',
      'temporary_diagnosis_id': diagTemporaryDiagnosisId,
      // Only relevant when a community report is being promoted into an
      // official case — not something this wizard does.
      'id_laporan_masyarakan': null,
    };
  }

  /// Lazily base64-encodes whichever photo slots have a local file — done
  /// right before submit, never at capture time, so drafts sitting around
  /// offline don't hold decoded image data in memory.
  Future<List<String>> encodePhotoFiles() async {
    final encoded = <String>[];
    for (final path in photoPaths) {
      if (path == null) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      encoded.add('data:image/jpeg;base64,${base64Encode(bytes)}');
    }
    return encoded;
  }

  static List<String> _asStringList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : <String>[];

  static int? _asInt(dynamic v) =>
      v is int ? v : (v == null ? null : int.tryParse(v.toString()));

  static double? _asDouble(dynamic v) =>
      v is double ? v : (v == null ? null : double.tryParse(v.toString()));

  /// Reverses [toPayload] — reloads a locally-saved draft's flat JSON back
  /// into the wizard's fields, for editing a not-yet-synced report instead
  /// of always starting a blank one. [clientId] overrides the fresh one
  /// generated in [initState] so saving continues to update the same
  /// `local_reports` row rather than creating a new one.
  void hydrateFromPayload(Map<String, dynamic> payload, String newClientId) {
    clientId = newClientId;

    reporterOccupation = payload['occupation']?.toString() ?? reporterOccupation;
    reporterPhone = payload['phone']?.toString() ?? reporterPhone;
    reporterAddress = payload['address']?.toString() ?? reporterAddress;
    reporterCaseFound = payload['case_found'] == true;
    // reporterName/reporterGender stay whatever initState pre-filled from the
    // *current* login session — identity data, not per-draft.

    locUptId = payload['upt_id'];
    locUptType = payload['upt_type']?.toString();
    locUptName = payload['upt_name']?.toString();
    locLocationName = payload['location_name']?.toString();
    locConservationType = payload['conservation_type']?.toString();
    locInsituConservation = _asStringList(payload['insitu_conservation']);
    locInsituOther = payload['insitu_other']?.toString();
    locExsituConservation = _asStringList(payload['exsitu_conservation']);
    locProvinceId = payload['province_id'];
    locDistrictId = payload['district_id'];
    locSubdistrictId = payload['subdistrict_id'];
    locVillageId = payload['village_id'];
    locLocationDescription = payload['location_description']?.toString();
    locLatitude = _asDouble(payload['latitude']);
    locLongitude = _asDouble(payload['longitude']);

    specProtected = payload['protected'] == true;
    specSelectedId = payload['species_id'];
    specName = payload['species_name']?.toString();
    specLatinName = payload['species_latin_name']?.toString();
    specFamily = payload['species_family']?.toString();
    specAge = payload['species_age']?.toString();
    specPopulation = _asInt(payload['population']);

    final reportDate = DateTime.tryParse(payload['report_date']?.toString() ?? '');
    if (reportDate != null) diagReportDate = reportDate;
    diagDead = _asInt(payload['dead']) ?? 0;
    diagDeadSign = _asStringList(payload['dead_sign']);
    diagDeadSignOther = payload['dead_sign_other']?.toString();
    diagLive = _asInt(payload['live']) ?? 0;
    diagLiveSign = _asStringList(payload['live_sign']);
    diagLiveSignOther = payload['live_sign_other']?.toString();
    diagChronological = payload['chronological']?.toString();
    diagSampling = payload['sampling']?.toString();
    diagFollowUp = payload['follow_up']?.toString();
    diagDiagnosis = payload['diagnosis']?.toString();
    diagTemporaryDiagnosisId = payload['temporary_diagnosis_id'];
  }

  /// A saved draft's `file` list is already base64-encoded (per
  /// [encodePhotoFiles], run eagerly at save time) — not local paths, so
  /// there's nothing for [PhotoSlotWidget] to display directly. Writes each
  /// one back out to a temp file so editing a draft shows its existing
  /// photos and re-encodes them the same lazy way on the next save/submit.
  Future<void> hydratePhotosFromBase64(List<dynamic> files) async {
    if (files.isEmpty) return;
    final dir = await getTemporaryDirectory();
    for (var i = 0; i < files.length && i < photoPaths.length; i++) {
      final raw = files[i]?.toString();
      if (raw == null) continue;
      final base64Data = raw.contains(',') ? raw.split(',').last : raw;
      try {
        final bytes = base64Decode(base64Data);
        final path =
            '${dir.path}/draft_${clientId}_$i.jpg';
        await File(path).writeAsBytes(bytes);
        photoPaths[i] = path;
      } catch (_) {
        // Corrupt/unexpected entry — leave that slot empty rather than crash.
      }
    }
  }
}
