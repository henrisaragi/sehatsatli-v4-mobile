/// Display fields from the `GET user` response (backend v4):
/// `{id, email, nama_lengkap, no_hp, status, roles: [{name}], permissions}`.
class UserProfileFields {
  UserProfileFields(this.raw);

  final Map<String, dynamic>? raw;

  String? _pick(String key) {
    final value = raw?[key];
    if (value == null || value.toString().trim().isEmpty) return null;
    return value.toString();
  }

  dynamic get id => raw?['id'];

  String get name => _pick('nama_lengkap') ?? 'Pengguna';

  String? get email => _pick('email');

  String? get phone => _pick('no_hp');

  /// First role name made readable (`upt-ksda` → `Upt Ksda`), or `-`.
  String get role {
    final roles = raw?['roles'];
    if (roles is List && roles.isNotEmpty && roles.first is Map) {
      final name = (roles.first as Map)['name']?.toString() ?? '';
      if (name.isNotEmpty) {
        return name
            .split(RegExp(r'[-_]'))
            .where((w) => w.isNotEmpty)
            .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
            .join(' ');
      }
    }
    return '-';
  }
}
