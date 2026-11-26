import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/core/permissions/app_permissions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

/// First-launch page (before login/registration) that explains every device
/// permission in [kAppPermissions] and, once the user ticks consent, triggers
/// the system prompts for all of them.
class PermissionConsentWidget extends StatefulWidget {
  const PermissionConsentWidget({super.key});

  static String routeName = 'PermissionConsent';
  static String routePath = '/permissionConsent';

  @override
  State<PermissionConsentWidget> createState() =>
      _PermissionConsentWidgetState();
}

class _PermissionConsentWidgetState extends State<PermissionConsentWidget> {
  bool _agreed = false;
  bool _requesting = false;

  Future<void> _submit() async {
    setState(() => _requesting = true);
    await PermissionConsent.requestAll();
    if (!mounted) return;
    context.goNamed(SplashAuthWidget.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      width: 56.0,
                      height: 56.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.accent1,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(LucideIcons.shieldCheck,
                          color: theme.primary, size: 28.0),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Izin Akses Perangkat',
                    style: theme.headlineSmall.override(
                      font: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      fontSize: 22.0,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'SehatSatli digunakan untuk mencatat dan melaporkan kasus '
                    'kesehatan satwa liar langsung dari lapangan, termasuk di '
                    'area tanpa sinyal. Agar fitur tersebut berjalan, aplikasi '
                    'memerlukan izin berikut:',
                    style: theme.bodyMedium.override(
                      fontSize: 14.0,
                      color: theme.secondaryText,
                      lineHeight: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  for (final p in kAppPermissions) _PermissionTile(p),
                  const SizedBox(height: 4.0),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: theme.accent3,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.info, color: theme.info, size: 18.0),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            'Data hanya digunakan untuk keperluan pelaporan dan '
                            'surveilans kesehatan satwa liar oleh Ditjen KSDAE. '
                            'Anda tetap dapat menolak izin tertentu pada dialog '
                            'sistem berikutnya atau mengubahnya kapan saja di '
                            'Pengaturan perangkat; fitur terkait akan meminta '
                            'izin lagi saat dibutuhkan.',
                            style: theme.bodySmall.override(
                              fontSize: 12.0,
                              color: theme.primaryText,
                              lineHeight: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          context.pushNamed(PrivacyPolicyWidget.routeName),
                      child: Text(
                        'Baca Kebijakan Privasi',
                        style: theme.bodyMedium.override(
                          color: theme.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 16.0),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.alternate)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: _requesting
                        ? null
                        : (v) => setState(() => _agreed = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: theme.primary,
                    title: Text(
                      'Ya, saya setuju',
                      style: theme.bodyLarge.override(
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      'Saya telah membaca penjelasan di atas dan mengizinkan '
                      'SehatSatli meminta akses tersebut.',
                      style: theme.bodySmall.override(
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  SizedBox(
                    height: 48.0,
                    child: FilledButton(
                      onPressed: _agreed && !_requesting ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        disabledBackgroundColor: theme.alternate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                      child: _requesting
                          ? const SizedBox(
                              width: 20.0,
                              height: 20.0,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.0, color: Colors.white),
                            )
                          : Text(
                              'Setuju & Lanjutkan',
                              style: theme.labelLarge.override(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: _agreed
                                    ? Colors.white
                                    : theme.secondaryText,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile(this.item);

  final AppPermission item;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.0,
            height: 40.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.accent1,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(item.icon, color: theme.primary, size: 20.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.bodyLarge.override(
                    font: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                    fontWeight: FontWeight.w500,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  item.reason,
                  style: theme.bodyMedium.override(
                    color: theme.secondaryText,
                    lineHeight: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
