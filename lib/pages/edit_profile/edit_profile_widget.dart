import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../core/network/api_client.dart' show ApiNetworkException;
import '../../core/utils/error_bottom_sheet.dart';
import '../../core/utils/option_list.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/master_repository.dart';
import '../../data/repositories/user_repository.dart';

/// Self-service "Edit Profile" form, per docs/update-profile.md — saves to
/// `POST /api/users/save`, a distinct (and per the doc, actually working)
/// endpoint from the documented-broken `/update-user` in API_ENDPOINTS.md
/// §5, which is why this was left as a "coming soon" stub until now.
class EditProfileWidget extends StatefulWidget {
  const EditProfileWidget({super.key});

  static String routeName = 'EditProfile';
  static String routePath = '/editProfile';

  @override
  State<EditProfileWidget> createState() => _EditProfileWidgetState();
}

class _EditProfileWidgetState extends State<EditProfileWidget> {
  Map<String, dynamic> _raw = {};
  List<Map<String, dynamic>> _upts = [];

  String? _name;
  String? _email;
  String? _phone;
  String? _gender; // '1' = Laki-laki, '2' = Perempuan
  String? _occupation;
  dynamic _uptId;
  String? _uptType;
  String? _drhSpecialist;
  bool _isDoctor = false;

  bool _isSaving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final currentUser = FFAppState().currentUser;
    _raw = currentUser is Map ? Map<String, dynamic>.from(currentUser) : {};
    _name = _raw['name']?.toString();
    _email = _raw['email']?.toString();
    _phone = _raw['phone']?.toString();
    _gender = _raw['gender']?.toString();
    _occupation = _raw['occupation']?.toString();
    _uptId = _raw['upt_id'];
    _uptType = _raw['upt_type']?.toString();
    _drhSpecialist = _raw['drh_specialist']?.toString();
    final doctorFlag = _raw['is_doctor'];
    _isDoctor = doctorFlag == true || doctorFlag == 1 || doctorFlag == '1';
    _loadUpts();
  }

  Future<void> _loadUpts() async {
    final upts = await MasterRepository().getCachedUpts();
    if (!mounted) return;
    setState(() => _upts = extractOptionList(upts, ['upts', 'data']));
  }

  Future<void> _save() async {
    setState(() => _validationError = null);

    if ((_name ?? '').trim().isEmpty) {
      setState(() => _validationError = 'Nama wajib diisi.');
      return;
    }
    if ((_email ?? '').trim().isEmpty) {
      setState(() => _validationError = 'Email wajib diisi.');
      return;
    }
    if (_isDoctor && (_drhSpecialist ?? '').trim().isEmpty) {
      setState(() => _validationError =
          'Spesialisasi dokter wajib diisi untuk akun dokter hewan.');
      return;
    }

    final token = FFAppState().accessToken;
    if (token == null) {
      await showErrorBottomSheet(
          context, 'Sesi login tidak ditemukan — silakan masuk ulang.');
      return;
    }

    setState(() => _isSaving = true);

    final payload = {
      ..._raw,
      'name': _name,
      'email': _email,
      'phone': _phone,
      'gender': _gender,
      'occupation': _occupation,
      'upt_id': _uptId,
      'upt_type': _uptType,
      'drh_specialist': _drhSpecialist,
    };

    try {
      final result =
          await UserRepository().saveProfile(payload: payload, token: token);
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (!result.success) {
        await showErrorBottomSheet(
            context, result.message ?? 'Gagal menyimpan profil.');
        return;
      }

      final merged = {..._raw, ...payload, ...(result.user ?? {})};
      FFAppState().currentUser = merged;
      await AuthRepository().updatePersistedUser(merged);

      if (!mounted) return;
      showSnackbar(context, 'Profil berhasil diperbarui.');
      context.pop();
    } on ApiNetworkException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showErrorBottomSheet(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(8.0, 22.0, 20.0, 20.0),
                  child: Row(
                    children: [
                      FlutterFlowIconButton(
                        borderRadius: 8.0,
                        buttonSize: 40.0,
                        icon: Icon(LucideIcons.arrowLeft,
                            color: FlutterFlowTheme.of(context).primaryText),
                        onPressed: () => context.pop(),
                      ),
                      Text(
                        'Edit Profile',
                        style: FlutterFlowTheme.of(context).titleLarge.override(
                              font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold),
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TrainingModeBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFieldWidget(
                      label: 'Nama',
                      hint: 'Nama lengkap',
                      value: _name ?? '',
                      onChanged: (v) => _name = v,
                      variant: 'outlined',
                    ),
                    SizedBox(height: 16.0),
                    TextFieldWidget(
                      label: 'Email',
                      hint: 'nama@email.com',
                      value: _email ?? '',
                      onChanged: (v) => _email = v,
                      keyboardType: TextInputType.emailAddress,
                      variant: 'outlined',
                    ),
                    SizedBox(height: 16.0),
                    TextFieldWidget(
                      label: 'No. HP',
                      hint: '08xxxxxxxxxx',
                      value: _phone ?? '',
                      onChanged: (v) => _phone = v,
                      keyboardType: TextInputType.phone,
                      variant: 'outlined',
                    ),
                    SizedBox(height: 16.0),
                    _dropdown(
                      label: 'Jenis Kelamin',
                      value: _gender,
                      options: const [
                        {'id': '1', 'name': 'Laki-laki'},
                        {'id': '2', 'name': 'Perempuan'},
                      ],
                      onChanged: (v) => setState(() => _gender = v as String?),
                    ),
                    SizedBox(height: 16.0),
                    TextFieldWidget(
                      label: 'Pekerjaan',
                      hint: 'mis. Petugas Lapangan',
                      value: _occupation ?? '',
                      onChanged: (v) => _occupation = v,
                      variant: 'outlined',
                    ),
                    SizedBox(height: 16.0),
                    _dropdown(
                      label: 'UPT',
                      value: _uptId,
                      options: _upts,
                      onChanged: (v) {
                        final selected = _upts.firstWhere(
                          (u) => optionId(u) == v,
                          orElse: () => <String, dynamic>{},
                        );
                        setState(() {
                          _uptId = v;
                          _uptType = selected['type']?.toString();
                        });
                      },
                    ),
                    SizedBox(height: 16.0),
                    _readonlyField(label: 'Tipe UPT', value: _uptType),
                    if (_isDoctor) ...[
                      SizedBox(height: 16.0),
                      TextFieldWidget(
                        label: 'Spesialisasi Dokter',
                        hint: 'mis. Dokter Hewan Satwa Liar',
                        value: _drhSpecialist ?? '',
                        onChanged: (v) => _drhSpecialist = v,
                        variant: 'outlined',
                      ),
                    ],
                    if (_validationError != null) ...[
                      SizedBox(height: 16.0),
                      Text(_validationError!,
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                  color: FlutterFlowTheme.of(context).error)),
                    ],
                  ],
                ),
              ),
            ),
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
                      : Text('Simpan Perubahan',
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
                  value: optionId(opt), child: Text(optionLabel(opt))))
              .toList(),
          onChanged: options.isEmpty ? null : onChanged,
        ),
      ],
    );
  }

  Widget _readonlyField({required String label, required String? value}) {
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
}
