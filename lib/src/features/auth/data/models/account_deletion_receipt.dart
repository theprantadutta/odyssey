import 'package:equatable/equatable.dart';

/// What the server can truthfully say when a deletion is requested.
///
/// `DELETE /auth/account` used to answer `{"undeleted_files": n}` - the result
/// of work the request had just done inline - and this client threw the body
/// away. Both halves were wrong in the same direction: the server implied the
/// deletion was over, and the client had no way to know either way.
///
/// The endpoint now accepts the request, removes access, and hands the rest to a
/// background worker. So the only two facts it has are the two fields here:
/// access is gone, and the deletion is not finished yet. [deletionCompleted] is
/// false today for every response; it is read rather than assumed so that the
/// day the server can report completion, this client already does.
class AccountDeletionReceipt extends Equatable {
  const AccountDeletionReceipt({
    required this.requestId,
    required this.accessRevoked,
    required this.deletionCompleted,
    required this.alreadyRequested,
  });

  /// The server's durable record of the request.
  ///
  /// Worth keeping: once the request is accepted the account cannot sign in, so
  /// this is the only handle a support conversation has on the deletion.
  final String requestId;

  /// Whether the account can no longer be used. True once the server answers.
  final bool accessRevoked;

  /// Whether the data has actually been removed. Not something this endpoint
  /// can promise, so never shown to the user as though it had.
  final bool deletionCompleted;

  /// Whether this account had already asked. A second tap is not an error.
  final bool alreadyRequested;

  /// Reads a response body, tolerating one that is missing or unexpected.
  ///
  /// A deletion that the server accepted must not look like a failure to the
  /// client because a field was absent: the account is already locked out by the
  /// time this runs, so throwing here would strand the user on a screen they can
  /// no longer use. The defaults are the conservative ones - access gone,
  /// deletion not finished.
  factory AccountDeletionReceipt.fromJson(Object? json) {
    final map = json is Map ? json : const <String, dynamic>{};

    return AccountDeletionReceipt(
      requestId: map['request_id']?.toString() ?? '',
      accessRevoked: map['access_revoked'] as bool? ?? true,
      deletionCompleted: map['deletion_completed'] as bool? ?? false,
      alreadyRequested: map['already_requested'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [requestId, accessRevoked, deletionCompleted, alreadyRequested];
}
