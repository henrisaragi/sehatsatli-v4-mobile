import 'package:flutter_test/flutter_test.dart';
import 'package:sehat_satli/data/models/user_profile_fields.dart';

/// `GET user` (backend v4) shape — see `UserController::show`.
void main() {
  test('reads nama_lengkap, email and no_hp', () {
    final fields = UserProfileFields({
      'nama_lengkap': 'Budi Santoso',
      'email': 'budi@example.com',
      'no_hp': '0812',
    });

    expect(fields.name, 'Budi Santoso');
    expect(fields.email, 'budi@example.com');
    expect(fields.phone, '0812');
  });

  test('formats the first role name', () {
    final fields = UserProfileFields({
      'roles': [
        {'id': 2, 'name': 'upt-ksda'},
      ],
    });

    expect(fields.role, 'Upt Ksda');
  });

  test('falls back when fields are missing', () {
    expect(UserProfileFields(null).name, 'Pengguna');
    expect(UserProfileFields({}).role, '-');
    expect(UserProfileFields({'no_hp': '  '}).phone, isNull);
  });
}
