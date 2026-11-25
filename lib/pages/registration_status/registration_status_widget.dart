import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/core/network/api_client.dart';
import '/data/repositories/auth_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/core/network/api_error_text.dart';

/// Shown right after a successful login whenever the user isn't a fully
/// verified UPT staff member yet (docs-new-versions/login.md +
/// register-upt.md): never registered (404), `menunggu`, or `ditolak`.
/// Re-fetches `/api/registrasi/status` itself rather than trusting
/// whatever the login flow saw, so it stays correct if reopened later.
class RegistrationStatusWidget extends StatefulWidget {
  const RegistrationStatusWidget({super.key});

  static String routeName = 'RegistrationStatus';
  static String routePath = '/registrationStatus';

  @override
  State<RegistrationStatusWidget> createState() =>
      _RegistrationStatusWidgetState();
}

class _RegistrationStatusWidgetState extends State<RegistrationStatusWidget> {
  bool _loading = true;
  RegistrationStatusResult? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = FFAppState().accessToken;
    if (token == null || token.isEmpty) {
      context.goNamed(SplashAuthWidget.routeName);
      return;
    }
    setState(() => _loading = true);
    try {
      final status = await AuthRepository().fetchRegistrationStatus(token);
      if (!mounted) return;
      if (status.exists && status.statusVerifikasi == 'terverifikasi') {
        context.goNamed(DashboardWidget.routeName);
        return;
      }
      setState(() {
        _status = status;
        _loading = false;
      });
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() {
        _error = networkErrorText;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthRepository().logout();
    FFAppState().clearSession();
    if (!mounted) return;
    context.goNamed(SplashAuthWidget.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildMessageCard(
                      icon: LucideIcons.wifiOff,
                      iconColor: FlutterFlowTheme.of(context).error,
                      title: 'Gagal Memuat Status',
                      body: _error!,
                      actions: [_buildRetryButton()],
                    )
                  : _buildStatusBody(),
        ),
      ),
    );
  }

  Widget _buildStatusBody() {
    final status = _status!;
    if (!status.exists) {
      return _buildMessageCard(
        icon: LucideIcons.userPlus,
        iconColor: FlutterFlowTheme.of(context).primary,
        title: 'Belum Terdaftar sebagai Staff UPT',
        body:
            'Anda belum pernah mengajukan pendaftaran sebagai staff UPT. Daftar sekarang untuk mengakses fitur UPT.',
        actions: [
          _buildPrimaryButton(
              'Daftar Sekarang',
              () => context.pushNamed(RegisterUptWidget.routeName)),
          const SizedBox(height: 12.0),
          _buildTextButton('Keluar', _logout),
        ],
      );
    }

    if (status.statusVerifikasi == 'ditolak') {
      return _buildMessageCard(
        icon: LucideIcons.circleX,
        iconColor: FlutterFlowTheme.of(context).error,
        title: 'Pendaftaran Ditolak',
        body: status.alasanPenolakan ?? 'Pendaftaran Anda ditolak oleh admin.',
        actions: [
          _buildPrimaryButton(
              'Daftar Ulang',
              () => context.pushNamed(RegisterUptWidget.routeName)),
          const SizedBox(height: 12.0),
          _buildTextButton('Keluar', _logout),
        ],
      );
    }

    // menunggu
    return _buildMessageCard(
      icon: LucideIcons.clock,
      iconColor: FlutterFlowTheme.of(context).warning,
      title: 'Menunggu Persetujuan Admin',
      body:
          'Pendaftaran Anda sebagai staff UPT ${status.upt?['nama'] ?? ''} sedang menunggu persetujuan admin.',
      actions: [
        if (status.jabatan != null || status.nip != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              children: [
                if (status.unitOrganisasi?['nama_unit'] != null)
                  _buildDetailRow(
                      'Unit', status.unitOrganisasi!['nama_unit'].toString()),
                if (status.jabatan != null)
                  _buildDetailRow('Jabatan', status.jabatan!),
                if (status.nip != null) _buildDetailRow('NIP', status.nip!),
              ],
            ),
          ),
        _buildTextButton('Keluar', _logout),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: FlutterFlowTheme.of(context)
                  .bodySmall
                  .override(color: FlutterFlowTheme.of(context).secondaryText)),
          Text(value, style: FlutterFlowTheme.of(context).bodyMedium),
        ],
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required List<Widget> actions,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 56.0),
            const SizedBox(height: 20.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleLarge.override(
                    font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8.0),
            Text(
              body,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context)
                  .bodyMedium
                  .override(color: FlutterFlowTheme.of(context).secondaryText),
            ),
            const SizedBox(height: 28.0),
            ...actions,
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primary,
            borderRadius: BorderRadius.circular(10.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).labelLarge.override(
                color: FlutterFlowTheme.of(context).onPrimary,
                fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton() => _buildPrimaryButton('Coba Lagi', _load);

  Widget _buildTextButton(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: FlutterFlowTheme.of(context)
            .labelMedium
            .override(color: FlutterFlowTheme.of(context).primary),
      ),
    );
  }
}
