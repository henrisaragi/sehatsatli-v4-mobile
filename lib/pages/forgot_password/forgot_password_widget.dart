import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/step_indicator/step_indicator_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/core/network/api_client.dart';
import '/core/utils/error_bottom_sheet.dart';
import '/data/repositories/auth_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Guest "lupa password" flow (docs/reset-password.md) — three steps against
/// the OTP-based reset endpoints: request an OTP by email, verify it, then
/// submit a new password + confirmation. Distinct from
/// `AuthRepository.changePassword`, which needs an active session.
class ForgotPasswordWidget extends StatefulWidget {
  const ForgotPasswordWidget({super.key});

  static String routeName = 'ForgotPassword';
  static String routePath = '/forgotPassword';

  @override
  State<ForgotPasswordWidget> createState() => _ForgotPasswordWidgetState();
}

class _ForgotPasswordWidgetState extends State<ForgotPasswordWidget> {
  int _step = 1;
  String _email = '';
  String _otp = '';
  String _password = '';
  String _confirmPassword = '';
  bool _isSubmitting = false;
  String? _error;

  Future<void> _requestOtp() async {
    final email = _email.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Masukkan alamat email yang valid');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await AuthRepository().requestPasswordOtp(email);
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _isSubmitting = false;
          _error = result.message ?? 'Email tidak ditemukan';
        });
        return;
      }
      setState(() {
        _isSubmitting = false;
        _email = email;
        _step = 2;
      });
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorBottomSheet(context,
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otp.trim();
    if (otp.isEmpty) {
      setState(() => _error = 'Masukkan kode OTP');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await AuthRepository().verifyPasswordOtp(_email, otp);
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _isSubmitting = false;
          _error = result.message ?? 'Kode OTP salah atau sudah kedaluwarsa';
        });
        return;
      }
      setState(() {
        _isSubmitting = false;
        _otp = otp;
        _step = 3;
      });
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorBottomSheet(context,
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  Future<void> _resendOtp() async {
    if (_isSubmitting) return;
    setState(() => _error = null);
    try {
      final result = await AuthRepository().requestPasswordOtp(_email);
      if (!mounted) return;
      if (!result.success) {
        setState(() => _error = result.message ?? 'Gagal mengirim ulang OTP');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode OTP telah dikirim ulang')),
      );
    } on ApiNetworkException {
      if (!mounted) return;
      showErrorBottomSheet(context,
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  Future<void> _resetPassword() async {
    if (_password.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter');
      return;
    }
    if (_password != _confirmPassword) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await AuthRepository().resetPasswordWithOtp(
        _email,
        _otp,
        _password,
        _confirmPassword,
      );
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _isSubmitting = false;
          _error = result.message ?? 'Gagal mengubah password';
        });
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password berhasil diubah. Silakan masuk kembali.')),
      );
      context.goNamed(SplashAuthWidget.routeName);
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorBottomSheet(context,
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  void _back() {
    if (_isSubmitting) return;
    if (_step > 1) {
      setState(() {
        _step -= 1;
        _error = null;
      });
      return;
    }
    context.safePop();
  }

  String get _title {
    switch (_step) {
      case 2:
        return 'Verifikasi OTP';
      case 3:
        return 'Buat Password Baru';
      default:
        return 'Lupa Password';
    }
  }

  String get _subtitle {
    switch (_step) {
      case 2:
        return 'Masukkan kode OTP yang dikirim ke $_email';
      case 3:
        return 'Buat password baru untuk akun Anda';
      default:
        return 'Masukkan email akun Anda untuk menerima kode OTP';
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
            padding: EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _back,
                  child: Icon(
                    LucideIcons.arrowLeft,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                ),
                SizedBox(height: 20.0),
                StepIndicatorWidget(
                    currentStep: _step.toDouble(), totalSteps: 3),
                SizedBox(height: 28.0),
                Text(
                  _title,
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 8.0),
                Text(
                  _subtitle,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                      color: FlutterFlowTheme.of(context).secondaryText),
                ),
                SizedBox(height: 32.0),
                Expanded(
                  child: SingleChildScrollView(child: _buildStepBody()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 2:
        return _buildOtpStep();
      case 3:
        return _buildPasswordStep();
      default:
        return _buildEmailStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFieldWidget(
          label: 'Email',
          hint: 'nama@email.com',
          keyboardType: TextInputType.emailAddress,
          value: _email,
          onChanged: (v) => _email = v,
          variant: 'outlined',
          error: _error != null,
        ),
        ..._errorText(),
        SizedBox(height: 24.0),
        _buildSubmitButton('Kirim Kode OTP', _requestOtp),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFieldWidget(
          label: 'Kode OTP',
          hint: '6 digit kode',
          keyboardType: TextInputType.number,
          value: _otp,
          onChanged: (v) => _otp = v,
          variant: 'outlined',
          error: _error != null,
        ),
        ..._errorText(),
        SizedBox(height: 12.0),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: _isSubmitting ? null : _resendOtp,
            child: Text(
              'Kirim Ulang OTP',
              style: FlutterFlowTheme.of(context)
                  .labelMedium
                  .override(color: FlutterFlowTheme.of(context).primary),
            ),
          ),
        ),
        SizedBox(height: 12.0),
        _buildSubmitButton('Verifikasi', _verifyOtp),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFieldWidget(
          label: 'Password Baru',
          hint: '••••••••',
          obscureText: true,
          value: _password,
          onChanged: (v) => _password = v,
          variant: 'outlined',
          error: _error != null,
        ),
        SizedBox(height: 16.0),
        TextFieldWidget(
          label: 'Konfirmasi Password',
          hint: '••••••••',
          obscureText: true,
          value: _confirmPassword,
          onChanged: (v) => _confirmPassword = v,
          variant: 'outlined',
          error: _error != null,
        ),
        ..._errorText(),
        SizedBox(height: 24.0),
        _buildSubmitButton('Simpan Password Baru', _resetPassword),
      ],
    );
  }

  List<Widget> _errorText() {
    if (_error == null) return const [];
    return [
      SizedBox(height: 16.0),
      Text(
        _error!,
        style: FlutterFlowTheme.of(context)
            .bodySmall
            .override(color: FlutterFlowTheme.of(context).error),
      ),
    ];
  }

  Widget _buildSubmitButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: _isSubmitting ? null : onTap,
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
                    color: FlutterFlowTheme.of(context).onPrimary),
              )
            : Text(
                label,
                style: FlutterFlowTheme.of(context).labelLarge.override(
                    color: FlutterFlowTheme.of(context).onPrimary,
                    fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
