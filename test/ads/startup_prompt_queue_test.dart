import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/services/startup_prompt_queue.dart';

/// Ordering of the system prompts the app raises at launch.
///
/// Notification permission is requested from `main()`, the UMP consent form runs
/// in the background, and on iOS App Tracking Transparency follows it. These are
/// separate subsystems that each decide for themselves when to present a modal,
/// and nothing stopped two of them doing it at once - which draws one over the
/// other, or lets a tap meant for one answer the other. Consent answered by
/// accident is worse than consent not asked for.
void main() {
  setUp(() => StartupPromptQueue.instance.resetForTesting());

  test('prompts run one after another, in the order they were queued', () async {
    final queue = StartupPromptQueue.instance;
    final events = <String>[];

    Future<void> prompt(String name, Duration duration) async {
      events.add('$name:start');
      await Future<void>.delayed(duration);
      events.add('$name:end');
    }

    // Queued together, as the app queues them: nothing waits for the previous
    // one at the call site.
    final first = queue.enqueue('notifications', () => prompt('notifications',
        const Duration(milliseconds: 40)));
    final second = queue.enqueue('consent', () => prompt('consent',
        const Duration(milliseconds: 10)));
    final third = queue.enqueue('att', () => prompt('att', Duration.zero));

    await Future.wait([first, second, third]);

    // No interleaving. The deliberately slow first prompt does not let the
    // quick ones overtake it.
    expect(events, [
      'notifications:start',
      'notifications:end',
      'consent:start',
      'consent:end',
      'att:start',
      'att:end',
    ]);
  });

  test('a prompt that throws does not block the ones behind it', () async {
    final queue = StartupPromptQueue.instance;
    final ran = <String>[];

    final failing = queue.enqueue<String>('consent', () async {
      ran.add('consent');
      throw StateError('the form could not be loaded');
    });

    final following = queue.enqueue<String>('att', () async {
      ran.add('att');
      return 'done';
    });

    // The queue's job is ordering, not error handling. One subsystem failing
    // must not leave the rest waiting forever behind it.
    expect(await failing, isNull);
    expect(await following, 'done');
    expect(ran, ['consent', 'att']);
  });

  test('a failed prompt reports null rather than throwing at the caller', () async {
    final result = await StartupPromptQueue.instance.enqueue<bool>(
      'consent',
      () async => throw Exception('UMP unavailable'),
    );

    // The caller decides what an unanswered prompt means. For consent it means
    // no ads; making it throw would take the app's startup down with it.
    expect(result, isNull);
  });

  test('a prompt result is handed back to its own caller', () async {
    final queue = StartupPromptQueue.instance;

    final a = queue.enqueue('a', () async => 1);
    final b = queue.enqueue('b', () async => 2);

    expect(await a, 1);
    expect(await b, 2);
  });

  test('settled waits for the queue without adding to it', () async {
    final queue = StartupPromptQueue.instance;
    var finished = false;

    queue.enqueue('slow', () async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      finished = true;
    });

    await queue.settled();
    expect(finished, isTrue);
  });

  test('prompts queued later still run after the queue has drained', () async {
    final queue = StartupPromptQueue.instance;
    final ran = <String>[];

    await queue.enqueue('first', () async => ran.add('first'));

    // The privacy options form is opened from settings, long after startup. The
    // queue has to still work once it has emptied.
    await queue.enqueue('privacy-options', () async => ran.add('privacy-options'));

    expect(ran, ['first', 'privacy-options']);
  });
}
