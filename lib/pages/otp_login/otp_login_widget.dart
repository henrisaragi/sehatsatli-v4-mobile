import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/text_field/text_field_widget.dart';
import '/core/network/api_client.dart';
import '/core/utils/error_bottom_sheet.dart';
import '/data/repositories/auth_repository.dart';
import '/data/repositories/master_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// Step 2 of the v4 login flow (docs-new-versions/login.md) — OTP entry,
/// reached from `SplashAuthWidget` after `AuthRepository.requestLoginOtp`
/// succeeds. There is no resend endpoint: once `login_token` expires (or
/// hits 5 wrong attempts), the user must restart from step 1.
class OtpLoginWidget extends StatefulWidget {
  const OtpLoginWidget({
    super.key,
    required this.email,
    required this.loginToken,
    this.expiresIn,
  });

  final String email;
  final String loginToken;
  final int? expiresIn;

  static String routeName = 'OtpLogin';
  static String routePath = '/otpLogin';

  @override
  State<OtpLoginWidget> createState() => _OtpLoginWidgetState();
}

class _OtpLoginWidgetState extends State<OtpLoginWidget> {
  String _otp = '';
  bool _isSubmitting = false;
  String? _error;
  bool _tokenInvalid = false;

  late int _secondsLeft = widget.expiresIn ?? 300;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _expired => _secondsLeft <= 0;

  String get _countdownLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _verify() async {
    final otp = _otp.trim();
    if (otp.isEmpty) {
      setState(() => _error = 'Masukkan kode OTP');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _tokenInvalid = false;
    });

    try {
      final result =
          await AuthRepository().verifyLoginOtp(widget.loginToken, otp);
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isSubmitting = false;
          _error = result.message ??
              (result.attemptsRemaining != null
                  ? 'OTP salah.'
                  : 'OTP kedaluwarsa atau tidak valid.');
          _tokenInvalid = result.tokenInvalid;
        });
        return;
      }

      final token = result.accessToken!;
      FFAppState().accessToken = token;
      FFAppState().currentUser = await AuthRepository().fetchCurrentUser(token);
      MasterRepository().refreshAll(token: token);

      final status = await AuthRepository().fetchRegistrationStatus(token);
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      if (status.exists && status.statusVerifikasi == 'terverifikasi') {
        context.goNamed(DashboardWidget.routeName);
      } else {
        context.goNamed(RegistrationStatusWidget.routeName);
      }
    } on ApiRateLimitException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorBottomSheet(
          context, 'Terlalu banyak percobaan, coba lagi nanti.');
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorBottomSheet(context,
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  void _backToLogin() {
    context.goNamed(SplashAuthWidget.routeName);
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
                  onTap: _isSubmitting ? null : _backToLogin,
                  child: Icon(
                    LucideIcons.arrowLeft,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                ),
                const SizedBox(height: 28.0),
                Text(
                  'Verifikasi OTP',
                  style: FlutterFlowTheme.of(context).titleLarge.override(
                        font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Masukkan kode OTP yang dikirim ke ${widget.email}',
                  style: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(color: FlutterFlowTheme.of(context).secondaryText),
                ),
                const SizedBox(height: 32.0),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
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
                        const SizedBox(height: 12.0),
                        Text(
                          _expired
                              ? 'Kode kedaluwarsa'
                              : 'Kode berlaku selama $_countdownLabel',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                color: _expired
                                    ? FlutterFlowTheme.of(context).error
                                    : FlutterFlowTheme.of(context).secondaryText,
                              ),
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
                        if (_expired || _tokenInvalid)
                          _buildActionButton('Login Ulang', _backToLogin)
                        else
                          _buildActionButton('Verifikasi', _verify),
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

  Widget _buildActionButton(String label, VoidCallback onTap) {
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
                    strokeWidth: 2, color: FlutterFlowTheme.of(context).onPrimary),
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
