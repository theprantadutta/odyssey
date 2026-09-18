import '../services/logger_service.dart';

/// Tracks which account the app is currently working on behalf of.
///
/// Everything user-scoped - the sync queue, cached rows, entitlements, temporary
/// unlocks - belongs to exactly one account. Without an explicit owner, work
/// started under one account could land after another has signed in: a response
/// in flight during logout would write the previous user's data into the new
/// user's database, and a queued operation could be sent under the wrong token.
///
/// [generation] increments on every sign-in and sign-out. Long-running work
/// captures it at the start and checks it again before writing anything; if it
/// has moved on, the result belongs to a session that no longer exists and is
/// dropped.
class AccountSession {
  AccountSession._();
  static final AccountSession _instance = AccountSession._();
  factory AccountSession() => _instance;

  String? _userId;
  int _generation = 0;

  /// The signed-in account, or null when signed out.
  String? get userId => _userId;

  /// Monotonic counter identifying the current session.
  int get generation => _generation;

  bool get isSignedIn => _userId != null;

  /// Opens a session for [userId], ending any previous one.
  ///
  /// Returns the new generation so the caller can scope its own work to it.
  int begin(String userId) {
    if (_userId == userId) return _generation;

    _userId = userId;
    _generation++;
    AppLogger.info('Account session $_generation opened');
    return _generation;
  }

  /// Ends the current session. Work tagged with the old generation stops being
  /// allowed to write.
  void end() {
    if (_userId == null) return;

    _userId = null;
    _generation++;
    AppLogger.info('Account session ended (now $_generation)');
  }

  /// Whether [generation] is still the live session.
  bool isCurrent(int generation) => generation == _generation;

  /// Whether [generation] still belongs to [userId]'s live session.
  ///
  /// Both are checked because a sign-out followed by the *same* account signing
  /// back in is still a different session: anything in flight across that
  /// boundary raced the database being cleared.
  bool isCurrentFor(int generation, String? userId) =>
      generation == _generation && userId == _userId;

  /// Runs [action] only if [generation] is still current, so a late response
  /// from a previous account is discarded rather than written.
  Future<void> guard(int generation, Future<void> Function() action) async {
    if (!isCurrent(generation)) {
      AppLogger.warning(
          'Dropped work from session $generation; current is $_generation');
      return;
    }
    await action();
  }

  /// Takes a snapshot of the live session, to be checked again later.
  ///
  /// Captured *before* the slow part of a piece of work - a network request,
  /// typically - and checked again before anything is written. The database is
  /// a single file shared by whichever account is signed in, and repositories
  /// resolve it freshly on every use, so a response that arrives after a sign
  /// out writes into whatever account is signed in by then.
  SessionScope capture() => SessionScope._(_generation, _userId);
}

/// The session that was live when a piece of work started.
///
/// The pattern this exists for:
///
/// ```dart
/// final scope = AccountSession().capture();
/// final response = await _dioClient.get(...);   // slow; the account can change
/// await scope.write(() => _db.tripsDao.upsert(...));
/// ```
///
/// Capturing after the request, or checking only once at the end of a batch,
/// both reintroduce the race. The snapshot has to be older than the await it is
/// protecting.
class SessionScope {
  SessionScope._(this.generation, this.userId);

  final int generation;
  final String? userId;

  /// Whether the account this work began under is still the signed-in one.
  ///
  /// Both the generation and the account are compared, so signing out and back
  /// in as the same person still counts as a different session - the database
  /// was cleared in between, and work spanning that is stale either way.
  bool get isCurrent => AccountSession().isCurrentFor(generation, userId);

  /// Performs [action] only if this session is still live.
  ///
  /// Returns whether it ran, for callers that need to avoid reporting success
  /// for a write that never happened.
  Future<bool> write(Future<void> Function() action) async {
    if (!isCurrent) {
      AppLogger.warning(
          'Dropped a write from session $generation; '
          'current is ${AccountSession().generation}');
      return false;
    }

    await action();
    return true;
  }
}
