import 'package:flutter_test/flutter_test.dart';
import 'package:sehat_satli/data/models/user_profile_fields.dart';

/// Covers revisi.md bug note #2 (Tipe UPT/Nama UPT auto-fill from the
/// logged-in user's nested `data.user.upt_type`/`upt_id`) — by the time this
/// class is constructed the caller has already unwrapped `data.user` (see
/// `AuthRepository.login()`), so these getters just need correct flat-key
/// extraction and to degrade gracefully when the value is absent.
void main() {
  group('uptType', () {
    test('reads the confirmed upt_type key', () {
      expect(UserProfileFields({'upt_type': 'PUSAT'}).uptType, 'PUSAT');
    });

    test('is null when absent', () {
      expect(UserProfileFields({}).uptType, isNull);
      expect(UserProfileFields(null).uptType, isNull);
    });
  });

  group('uptId', () {
    test('passes through whatever type the server sent (numeric id)', () {
      expect(UserProfileFields({'upt_id': 1}).uptId, 1);
    });

    test('is null when absent', () {
      expect(UserProfileFields({}).uptId, isNull);
      expect(UserProfileFields(null).uptId, isNull);
    });
  });
}
