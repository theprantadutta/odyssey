import 'dart:async';

import 'logger_service.dart';

/// Presents system prompts one at a time.
///
/// The app asks for several things at launch: notification permission, UMP
/// consent, and on iOS App Tracking Transparency. These are separate subsystems
/// that each decide for themselves when to show a modal, and nothing stopped two
/// of them being presented at once.
///
/// When that happens the outcome depends on the platform and is never good: one
/// prompt is drawn over the other, or silently dropped, or answered by a tap the
/// user meant for the one underneath. Consent answered by accident is worse than
/// consent not asked for.
///
/// Queuing them costs a little time at launch and makes the sequence
/// deterministic.
class StartupPromptQueue {
  StartupPromptQueue._();
  static final StartupPromptQueue instance = StartupPromptQueue._();

  Future<void> _tail = Future<void>.value();

  /// Runs [prompt] once everything queued before it has finished.
  ///
  /// A prompt that throws does not block what follows: the queue's job is
  /// ordering, not error handling, and one subsystem failing must not leave the
  /// others waiting.
  Future<T?> enqueue<T>(String name, Future<T> Function() prompt) {
    final completer = Completer<T?>();

    _tail = _tail.then((_) async {
      try {
        AppLogger.debug('Startup prompt: $name');
        completer.complete(await prompt());
      } catch (e, st) {
        AppLogger.error('Startup prompt "$name" failed', e, st);
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// Waits for everything currently queued, without adding to it.
  Future<void> settled() => _tail;

  /// Drops the queue. For tests only.
  void resetForTesting() => _tail = Future<void>.value();
}
