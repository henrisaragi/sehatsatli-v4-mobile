import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One device permission the app asks for, with the wording shown on the
/// consent page. Every permission the app uses must be listed in [kAppPermissions]
/// (see `.claude/skills/device-permission/SKILL.md`).
class AppPermission {
  const AppPermission({
    required this.permission,
    required this.icon,
    required this.title,
    required this.reason,
  });

  final Permission permission;
  final IconData icon;
  final String title;
  final String reason;
}

const List<AppPermission> kAppPermissions = [
  AppPermission(
    permission: Permission.camera,
    icon: LucideIcons.camera,
    title: 'Kamera',
    reason: 'Untuk memotret satwa, kondisi lapangan, dan barang bukti yang '
        'dilampirkan pada laporan kasus.',
  ),
  AppPermission(
    permission: Permission.locationWhenInUse,
    icon: LucideIcons.mapPin,
    title: 'Lokasi (saat aplikasi digunakan)',
    reason: 'Untuk mengisi koordinat GPS lokasi kejadian secara otomatis, '
        'termasuk saat tanpa sinyal. Lokasi tidak dilacak di latar belakang.',
  ),
  AppPermission(
    permission: Permission.notification,
    icon: LucideIcons.bell,
    title: 'Notifikasi',
    reason: 'Untuk memberi tahu Anda saat laporan diverifikasi, ditolak, '
        'atau membutuhkan tindak lanjut.',
  ),
];

/// Whether the one-time consent page (shown on first launch, before login)
/// has been completed on this install.
class PermissionConsent {
  // Bump the suffix when a new permission is added to [kAppPermissions] so
  // existing installs see the page again and are asked for it.
  static const _prefsKey = 'permission_consent_v1';

  static Future<bool> isCompleted() async =>
      (await SharedPreferences.getInstance()).getBool(_prefsKey) ?? false;

  /// Shows the system prompts for every permission (already-decided ones are
  /// skipped by the OS), then records consent. Denials are respected: features
  /// ask again at the point of use and the app keeps working without them.
  static Future<void> requestAll() async {
    try {
      await kAppPermissions.map((p) => p.permission).toList().request();
    } catch (_) {
      // Unsupported platform (web) or a request already in flight.
    }
    await (await SharedPreferences.getInstance()).setBool(_prefsKey, true);
  }
}
