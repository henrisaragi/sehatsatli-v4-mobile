import 'package:flutter_test/flutter_test.dart';
import 'package:sehat_satli/app_state.dart';

/// Covers the client-side half of tasks.md Fase 7's "uji multi-role" item —
/// verifying `FFAppState`'s RBAC/scope flags are read correctly from the
/// login-response user map. The other half (confirming the *server* actually
/// scopes data by `upt_id` per user) needs live accounts of different roles
/// against the real backend and can't be exercised from a unit test.
void main() {
  tearDown(() {
    FFAppState.reset();
  });

  group('RBAC flags — truthy encodings', () {
    test('accepts bool true', () {
      FFAppState().currentUser = {'is_doctor': true, 'heads_upt': true};
      expect(FFAppState().isDoctor, isTrue);
      expect(FFAppState().headsUpt, isTrue);
    });

    test('accepts int 1', () {
      FFAppState().currentUser = {'training_mode': 1, 'all_notification': 1};
      expect(FFAppState().trainingMode, isTrue);
      expect(FFAppState().allNotification, isTrue);
    });

    test('accepts string "1"', () {
      FFAppState().currentUser = {'is_doctor': '1', 'reset_password': '1'};
      expect(FFAppState().isDoctor, isTrue);
      expect(FFAppState().mustResetPassword, isTrue);
    });

    test('rejects false/0/"0"/missing', () {
      FFAppState().currentUser = {
        'is_doctor': false,
        'heads_upt': 0,
        'training_mode': '0',
      };
      expect(FFAppState().isDoctor, isFalse);
      expect(FFAppState().headsUpt, isFalse);
      expect(FFAppState().trainingMode, isFalse);
      expect(FFAppState().allNotification, isFalse); // field absent entirely
    });
  });

  group('uptId', () {
    test('parses an int upt_id', () {
      FFAppState().currentUser = {'upt_id': 5};
      expect(FFAppState().uptId, 5);
    });

    test('parses a numeric-string upt_id', () {
      FFAppState().currentUser = {'upt_id': '7'};
      expect(FFAppState().uptId, 7);
    });

    test('is null when absent or unparseable', () {
      FFAppState().currentUser = {'upt_id': 'not-a-number'};
      expect(FFAppState().uptId, isNull);
      FFAppState().currentUser = {};
      expect(FFAppState().uptId, isNull);
    });
  });

  group('currentUser missing entirely', () {
    test('every RBAC getter degrades to false/null instead of throwing', () {
      FFAppState().currentUser = null;
      expect(FFAppState().isDoctor, isFalse);
      expect(FFAppState().headsUpt, isFalse);
      expect(FFAppState().trainingMode, isFalse);
      expect(FFAppState().allNotification, isFalse);
      expect(FFAppState().mustResetPassword, isFalse);
      expect(FFAppState().uptId, isNull);
    });
  });
}
