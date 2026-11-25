import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/search_select/search_select_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/core/network/api_client.dart';
import '/core/utils/error_bottom_sheet.dart';
import '/data/repositories/registration_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/core/network/api_error_text.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _nipRegex = RegExp(r'^\d{18}$');

/// Guest UPT staff self-registration (docs-new-versions/register-upt.md) —
/// new in backend v4, no equivalent in the old API. Account is created
/// immediately in `menunggu` status; approval happens separately (see
/// `RegistrationStatusWidget`).
class RegisterUptWidget extends StatefulWidget {
  const RegisterUptWidget({super.key});

  static String routeName = 'RegisterUpt';
  static String routePath = '/registerUpt';

  @override
  State<RegisterUptWidget> createState() => _RegisterUptWidgetState();
}

class _RegisterUptWidgetState extends State<RegisterUptWidget> {
  String? _kategori;
  bool _loadingUpt = true;
  List<Map<String, dynamic>> _uptOptions = const [];

  String? _selectedUptId;
  String? _selectedUptNama;

  bool _loadingUnit = false;
  List<Map<String, dynamic>> _unitOptions = const [];
  String? _selectedUnitId;
  String? _selectedUnitNama;

  String _nama = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  String _nip = '';
  String _jabatan = '';

  bool _passwordVisible = false;
  bool _confirmVisible = false;

  bool _isSubmitting = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _loadUptList();
  }

  Future<void> _loadUptList() async {
    setState(() => _loadingUpt = true);
    try {
      final options =
          await RegistrationRepository().fetchUptList(kategori: _kategori);
      if (!mounted) return;
      setState(() {
        _uptOptions = options;
        _loadingUpt = false;
      });
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() {
        _uptOptions = const [];
        _loadingUpt = false;
      });
      showSnackbar(context, 'Daftar UPT gagal dimuat. $networkErrorText');
    }
  }

  Future<void> _onUptSelected(Map<String, dynamic> upt) async {
    setState(() {
      _selectedUptId = upt['id']?.toString();
      _selectedUptNama = upt['nama'] as String?;
      // Reset the dependent dropdown whenever the UPT changes.
      _selectedUnitId = null;
      _selectedUnitNama = null;
      _unitOptions = const [];
      _loadingUnit = true;
    });

    try {
      final options = await RegistrationRepository()
          .fetchUnitOrganisasi(_selectedUptId!);
      if (!mounted) return;
      setState(() {
        _unitOptions = options;
        _loadingUnit = false;
      });
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() {
        _unitOptions = const [];
        _loadingUnit = false;
      });
      showSnackbar(context, 'Daftar unit organisasi gagal dimuat. $networkErrorText');
    }
  }

  void _onKategoriChanged(String? kategori) {
    setState(() {
      _kategori = kategori;
      _selectedUptId = null;
      _selectedUptNama = null;
      _selectedUnitId = null;
      _selectedUnitNama = null;
      _unitOptions = const [];
    });
    _loadUptList();
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_nama.trim().isEmpty) {
      errors['nama'] = 'Nama wajib diisi';
    } else if (_nama.trim().length > 150) {
      errors['nama'] = 'Nama maksimal 150 karakter';
    }
    if (_email.trim().isEmpty || !_emailRegex.hasMatch(_email.trim())) {
      errors['email'] = 'Masukkan alamat email yang valid';
    }
    if (_password.length < 8) {
      errors['password'] = 'Password minimal 8 karakter';
    } else if (_password != _confirmPassword) {
      errors['password_confirmation'] = 'Konfirmasi password tidak cocok';
    }
    if (_selectedUptId == null) {
      errors['upt_id'] = 'Pilih UPT';
    }
    if (_selectedUnitId == null) {
      errors['unit_organisasi_id'] = 'Pilih unit organisasi';
    }
    if (!_nipRegex.hasMatch(_nip.trim())) {
      errors['nip'] = 'NIP harus persis 18 digit angka';
    }
    if (_jabatan.trim().isEmpty) {
      errors['jabatan'] = 'Jabatan wajib diisi';
    } else if (_jabatan.trim().length > 100) {
      errors['jabatan'] = 'Jabatan maksimal 100 karakter';
    }
    return errors;
  }

  Future<void> _submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _fieldErrors = errors;
        _error = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _fieldErrors = const {};
      _error = null;
    });

    try {
      final result = await RegistrationRepository().submitRegistration(
        nama: _nama.trim(),
        email: _email.trim(),
        password: _password,
        passwordConfirmation: _confirmPassword,
        uptId: _selectedUptId!,
        unitOrganisasiId: _selectedUnitId!,
        nip: _nip.trim(),
        jabatan: _jabatan.trim(),
      );
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isSubmitting = false;
          _fieldErrors = result.fieldErrors;
          _error = result.fieldErrors.isEmpty ? result.message : null;
        });
        return;
      }

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Registrasi berhasil, silakan verifikasi email Anda.')),
      );
      context.goNamed(SplashAuthWidget.routeName);
    } on ApiRateLimitException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorBottomSheet(
          context, rateLimitText);
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorBottomSheet(context,
          networkErrorText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _isSubmitting ? null : () => context.safePop(),
                  child: Icon(
                    LucideIcons.arrowLeft,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                ),
                const SizedBox(height: 20.0),
                Text(
                  'Registrasi Staff UPT',
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Daftar sebagai staff Unit Pelaksana Teknis',
                  style: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(color: FlutterFlowTheme.of(context).secondaryText),
                ),
                const SizedBox(height: 24.0),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildKategoriFilter(),
                        const SizedBox(height: 16.0),
                        _loadingUpt
                            ? _buildLoadingField('UPT')
                            : SearchSelectWidget(
                                label: 'UPT',
                                hint: 'Cari UPT...',
                                options: _uptOptions,
                                selectedId: _selectedUptId,
                                selectedLabel: _selectedUptNama,
                                optionLabel: (o) => o['nama']?.toString() ?? '',
                                optionId: (o) => o['id']?.toString(),
                                onSelected: _onUptSelected,
                              ),
                        if (_fieldErrors['upt_id'] != null) ..._fieldError('upt_id'),
                        const SizedBox(height: 16.0),
                        _selectedUptId == null
                            ? _buildLoadingField('Unit Organisasi', disabled: true)
                            : _loadingUnit
                                ? _buildLoadingField('Unit Organisasi')
                                : SearchSelectWidget(
                                    label: 'Unit Organisasi',
                                    hint: 'Cari unit organisasi...',
                                    options: _unitOptions,
                                    selectedId: _selectedUnitId,
                                    selectedLabel: _selectedUnitNama,
                                    optionLabel: (o) =>
                                        ('  ' * ((o['level'] as int?) ?? 0)) +
                                        (o['nama_unit']?.toString() ?? ''),
                                    optionId: (o) => o['id']?.toString(),
                                    onSelected: (o) => setState(() {
                                      _selectedUnitId = o['id']?.toString();
                                      _selectedUnitNama =
                                          o['nama_unit'] as String?;
                                    }),
                                  ),
                        if (_fieldErrors['unit_organisasi_id'] != null)
                          ..._fieldError('unit_organisasi_id'),
                        const SizedBox(height: 20.0),
                        TextFieldWidget(
                          label: 'Nama Lengkap',
                          hint: 'Nama sesuai identitas',
                          value: _nama,
                          onChanged: (v) => _nama = v,
                          variant: 'outlined',
                          helper: _fieldErrors['nama'] ?? '',
                          helperPresent: _fieldErrors['nama'] != null,
                          error: _fieldErrors['nama'] != null,
                        ),
                        const SizedBox(height: 16.0),
                        TextFieldWidget(
                          label: 'Email',
                          hint: 'nama@email.com',
                          keyboardType: TextInputType.emailAddress,
                          value: _email,
                          onChanged: (v) => _email = v,
                          variant: 'outlined',
                          helper: _fieldErrors['email'] ?? '',
                          helperPresent: _fieldErrors['email'] != null,
                          error: _fieldErrors['email'] != null,
                        ),
                        const SizedBox(height: 16.0),
                        TextFieldWidget(
                          label: 'Password',
                          hint: 'Minimal 8 karakter',
                          obscureText: !_passwordVisible,
                          value: _password,
                          onChanged: (v) => _password = v,
                          variant: 'outlined',
                          trailingIconPresent: true,
                          trailingIcon: Icon(
                            _passwordVisible
                                ? LucideIcons.eye
                                : Icons.visibility_off_rounded,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 20.0,
                          ),
                          onTrailingIconTap: () =>
                              setState(() => _passwordVisible = !_passwordVisible),
                          helper: _fieldErrors['password'] ?? '',
                          helperPresent: _fieldErrors['password'] != null,
                          error: _fieldErrors['password'] != null,
                        ),
                        const SizedBox(height: 16.0),
                        TextFieldWidget(
                          label: 'Konfirmasi Password',
                          hint: 'Ulangi password',
                          obscureText: !_confirmVisible,
                          value: _confirmPassword,
                          onChanged: (v) => _confirmPassword = v,
                          variant: 'outlined',
                          trailingIconPresent: true,
                          trailingIcon: Icon(
                            _confirmVisible
                                ? LucideIcons.eye
                                : Icons.visibility_off_rounded,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 20.0,
                          ),
                          onTrailingIconTap: () =>
                              setState(() => _confirmVisible = !_confirmVisible),
                          helper: _fieldErrors['password_confirmation'] ?? '',
                          helperPresent:
                              _fieldErrors['password_confirmation'] != null,
                          error: _fieldErrors['password_confirmation'] != null,
                        ),
                        const SizedBox(height: 16.0),
                        TextFieldWidget(
                          label: 'NIP',
                          hint: '18 digit angka',
                          keyboardType: TextInputType.number,
                          value: _nip,
                          onChanged: (v) => _nip = v,
                          variant: 'outlined',
                          helper: _fieldErrors['nip'] ?? '',
                          helperPresent: _fieldErrors['nip'] != null,
                          error: _fieldErrors['nip'] != null,
                        ),
                        const SizedBox(height: 16.0),
                        TextFieldWidget(
                          label: 'Jabatan',
                          hint: 'Jabatan saat ini',
                          value: _jabatan,
                          onChanged: (v) => _jabatan = v,
                          variant: 'outlined',
                          helper: _fieldErrors['jabatan'] ?? '',
                          helperPresent: _fieldErrors['jabatan'] != null,
                          error: _fieldErrors['jabatan'] != null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16.0),
                          Text(
                            _error!,
                            style: FlutterFlowTheme.of(context)
                                .bodySmall
                                .override(color: FlutterFlowTheme.of(context).error),
                          ),
                        ],
                        const SizedBox(height: 24.0),
                        InkWell(
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
                                        color:
                                            FlutterFlowTheme.of(context).onPrimary),
                                  )
                                : Text(
                                    'Daftar',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                            color:
                                                FlutterFlowTheme.of(context)
                                                    .onPrimary,
                                            fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKategoriFilter() {
    final tabs = <MapEntry<String?, String>>[
      const MapEntry(null, 'Semua'),
      const MapEntry('TAMAN_NASIONAL', 'Taman Nasional'),
      const MapEntry('KSDA', 'KSDA'),
    ];
    return Row(
      children: tabs
          .map((tab) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(tab.value),
                  selected: _kategori == tab.key,
                  onSelected: (_) => _onKategoriChanged(tab.key),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLoadingField(String label, {bool disabled = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Text(
            label,
            style: FlutterFlowTheme.of(context)
                .labelMedium
                .override(fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: FlutterFlowTheme.of(context).alternate),
          ),
          child: Text(
            disabled ? 'Pilih UPT terlebih dahulu' : 'Memuat...',
            style: FlutterFlowTheme.of(context)
                .bodyMedium
                .override(color: FlutterFlowTheme.of(context).secondaryText),
          ),
        ),
      ],
    );
  }

  List<Widget> _fieldError(String key) => [
        const SizedBox(height: 4.0),
        Text(
          _fieldErrors[key]!,
          style: FlutterFlowTheme.of(context)
              .bodySmall
              .override(color: FlutterFlowTheme.of(context).error),
        ),
      ];
}
