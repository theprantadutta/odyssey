import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/features/auth/data/models/account_deletion_receipt.dart';

/// The client's half of the account-deletion wire contract.
///
/// `DELETE /auth/account` used to answer `{"undeleted_files": n}` and
/// `auth_repository.deleteAccount` was `Future<void>` and dropped the body, so
/// nothing on this side could tell an accepted request from a finished one -
/// and the UI said "deleted" either way. These check the field names the server
/// actually sends, and that the defaults for a body this client cannot read are
/// the ones that under-promise rather than over-promise.
void main() {
  group('AccountDeletionReceipt', () {
    test('reads the accepted-not-completed answer the endpoint sends', () {
      final receipt = AccountDeletionReceipt.fromJson(const {
        'request_id': '6f1c7b0e-0000-4000-8000-000000000001',
        'requested_at': '2026-09-18T06:00:00Z',
        'access_revoked': true,
        'deletion_completed': false,
        'already_requested': false,
      });

      expect(receipt.requestId, '6f1c7b0e-0000-4000-8000-000000000001');
      expect(receipt.accessRevoked, isTrue);

      // The one the UI keys off. The endpoint cannot claim this.
      expect(receipt.deletionCompleted, isFalse);
      expect(receipt.alreadyRequested, isFalse);
    });

    test('carries a repeat request through as a repeat, not an error', () {
      final receipt = AccountDeletionReceipt.fromJson(const {
        'request_id': '6f1c7b0e-0000-4000-8000-000000000001',
        'access_revoked': true,
        'deletion_completed': false,
        'already_requested': true,
      });

      expect(receipt.alreadyRequested, isTrue);
      expect(receipt.deletionCompleted, isFalse);
    });

    test('defaults to the conservative reading when the body is unusable', () {
      // By the time this runs the account is already locked out, so a body this
      // client cannot read must not become an exception on a screen the user can
      // no longer leave - and must never default to claiming the deletion is
      // done.
      for (final body in <Object?>[null, 'unexpected', const <String, dynamic>{}]) {
        final receipt = AccountDeletionReceipt.fromJson(body);

        expect(receipt.deletionCompleted, isFalse);
        expect(receipt.accessRevoked, isTrue);
        expect(receipt.requestId, isEmpty);
      }
    });
  });
}
