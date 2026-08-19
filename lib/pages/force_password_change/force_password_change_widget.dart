import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/text_field/text_field_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../../data/repositories/auth_repository.dart';

/// Mandatory password change forced on first login after an admin creates
/// an account with a default/temporary password (`user.reset_password ==
/// true`, see design-system.md and `FFAppState.mustResetPassword`). Reached
/// via the router `redirect` in nav.dart, which keeps sending the user back
/// here until the flag flips — there is deliberately no back button, only a
/// Logout escape hatch, since bypassing this isn't optional.
class ForcePasswordChangeWidget extends StatefulWidget {
  const ForcePasswordChangeWidget({super.key});

  static String routeName = 'ForcePasswordChange';
  static String routePath = '/forcePasswordChange';

  @override
  State<ForcePasswordChangeWidget> createState() =>
      _ForcePasswordChangeWidgetState();
}

class _ForcePasswordChangeWidgetState extends State<ForcePasswordChangeWidget> {
  String _password = '';
  String _confirmPassword = '';
  bool _isSubmitting = false;
  String? _error;

  Future<void> _submit() async {
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

    final result = await AuthRepository().changePassword(_password);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _isSubmitting = false;
        _error = result.message ?? 'Gagal mengubah password';
      });
      return;
    }

    // Server flips `reset_password` to 0 on success (design-system.md), but
    // the response doesn't hand back a fresh user object — mirror that
    // locally so the router's mandatory-redirect check clears immediately.
    final currentUser = FFAppState().currentUser;
    if (currentUser is Map) {
      final updated = {
        ...Map<String, dynamic>.from(currentUser),
        'reset_password': false,
      };
      FFAppState().currentUser = updated;
      await AuthRepository().updatePersistedUser(updated);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    context.goNamed(DashboardWidget.routeName);
  }

  Future<void> _logout() async {
    await AuthRepository().logout();
    FFAppState().accessToken = null;
    FFAppState().currentUser = null;
    if (!mounted) return;
    context.goNamed(SplashAuthWidget.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Column(
          children: [
            TrainingModeBanner(),
            Expanded(
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSubmitting ? null : _logout,
                            child: Text('Keluar',
                                style: FlutterFlowTheme.of(context)
                                    .labelLarge
                                    .override(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText)),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.0),
                      Container(
                        width: 72.0,
                        height: 72.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).accent2,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(LucideIcons.lockKeyhole,
                            color: FlutterFlowTheme.of(context).warning,
                            size: 36.0),
                      ),
                      SizedBox(height: 24.0),
                      Text(
                        'Buat Password Baru',
                        style: FlutterFlowTheme.of(context).titleLarge.override(
                              font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold),
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: 8.0),
                      Text(
                        'Akun Anda masih menggunakan password sementara dari admin. '
                        'Buat password baru untuk melanjutkan.',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                            color: FlutterFlowTheme.of(context).secondaryText),
                      ),
                      SizedBox(height: 32.0),
                      TextFieldWidget(
                        label: 'Password Baru',
                        hint: '••••••••',
                        obscureText: true,
                        value: _password,
                        onChanged: (v) => _password = v,
                        variant: 'outlined',
                      ),
                      SizedBox(height: 16.0),
                      TextFieldWidget(
                        label: 'Konfirmasi Password',
                        hint: '••••••••',
                        obscureText: true,
                        value: _confirmPassword,
                        onChanged: (v) => _confirmPassword = v,
                        variant: 'outlined',
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 16.0),
                        Text(_error!,
                            style: FlutterFlowTheme.of(context)
                                .bodySmall
                                .override(
                                    color: FlutterFlowTheme.of(context).error)),
                      ],
                      SizedBox(height: 24.0),
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
                                      color: FlutterFlowTheme.of(context)
                                          .onPrimary),
                                )
                              : Text('Simpan & Lanjutkan',
                                  style: FlutterFlowTheme.of(context)
                                      .labelLarge
                                      .override(
                                          color: FlutterFlowTheme.of(context)
                                              .onPrimary,
                                          fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
