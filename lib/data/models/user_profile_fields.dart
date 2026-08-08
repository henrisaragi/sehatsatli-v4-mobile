import '../../core/constants/api_endpoints.dart';

/// Defensive field extraction over the raw login-response (`/api/auth/login-app`)
/// user map. Most backend key names for these display fields aren't confirmed
/// against a live response (see memory `api-login-contract` for the same
/// caveat on the login contract itself), so each field tries several
/// plausible candidates before falling back to a placeholder.
///
/// Shared by [UserProfileSettingsWidget] (profile screen) and
/// [NewGeneralReportWidget] (Step 1 — reporter identity is pre-filled from
/// the logged-in user rather than typed in).
class UserProfileFields {
  UserProfileFields(this.raw);

  final Map<String, dynamic>? raw;

  String? _pick(List<String> keys) {
    if (raw == null) return null;
    for (final key in keys) {
      final value = raw![key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  dynamic get id => raw?['id'];

  String get name => _pick(['name', 'full_name', 'nama', 'username']) ?? 'Pengguna';

  String get role =>
      _pick(['position', 'jabatan', 'role', 'occupation', 'user_level_name']) ?? '-';

  String get nip => _pick(['nip', 'employee_id', 'nik']) ?? '-';

  String get institution =>
      _pick(['upt_name', 'instansi', 'unit_name', 'office_name']) ?? '';

  String? get phone => _pick(['phone', 'no_hp', 'no_telp', 'telp', 'hp', 'phone_number']);

  String? get address => _pick(['address', 'alamat']);

  /// Server encodes gender as an int — confirmed: 1 = Laki-laki, 2 = Perempuan.
  String? get gender {
    final value = _pick(['gender', 'jenis_kelamin', 'sex']);
    if (value == null) return null;
    switch (value.trim()) {
      case '1':
        return 'Laki-laki';
      case '2':
        return 'Perempuan';
      default:
        return value;
    }
  }

  String? get photoUrl {
    final value = _pick(['photo_url', 'avatar_url', 'photo', 'avatar', 'foto']);
    if (value == null) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return '${ApiEndpoints.baseUrl}$value';
  }
}
