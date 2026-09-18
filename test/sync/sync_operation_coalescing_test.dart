import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/sync/sync_operation_coalescing.dart';

/// Regression tests for F02: enqueueing used to delete every pending operation
/// for an entity and keep only the incoming one, so an offline create followed
/// by an edit left an update for an ID the server had never seen.

final DateTime t0 = DateTime.utc(2026, 1, 1, 10, 0);
final DateTime t1 = DateTime.utc(2026, 1, 1, 10, 5);
final DateTime tNow = DateTime.utc(2026, 1, 1, 11, 0);

QueuedOperation _op(
  String operation,
  Map<String, dynamic> payload, {
  String id = 'q1',
  DateTime? createdAt,
  String status = SyncStatus.pending,
}) {
  return QueuedOperation(
    id: id,
    operation: operation,
    payload: payload,
    createdAt: createdAt ?? t0,
    status: status,
  );
}

void main() {
  group('no existing operation', () {
    test('queues the incoming operation as-is', () {
      final result = coalesceOperation(
        existing: const [],
        incomingOperation: SyncOp.create,
        incomingPayload: {'title': 'Rome'},
        now: tNow,
      );

      expect(result.idsToDelete, isEmpty);
      expect(result.operation, SyncOp.create);
      expect(result.payload, {'title': 'Rome'});
      expect(result.createdAt, tNow);
    });
  });

  group('create + update', () {
    test('stays a create carrying the edited fields', () {
      // The original bug: this became a bare update for an ID the server has
      // never seen, and the server answered "Trip not found".
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.create, {
            'id': 'local-1',
            'title': 'Rome',
            'start_date': '2026-05-01',
          }),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'title': 'Rome 2026', kBaseVersionKey: '...'},
        now: tNow,
      );

      expect(result.operation, SyncOp.create);
      expect(result.payload, {
        'id': 'local-1',
        'title': 'Rome 2026',
        'start_date': '2026-05-01',
      });
      expect(result.idsToDelete, ['q1']);
    });

    test('drops the base version, since nothing exists server-side yet', () {
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.create, {'title': 'Rome'}),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'title': 'Milan', kBaseVersionKey: '2026-01-01'},
        now: tNow,
      );

      expect(result.payload!.containsKey(kBaseVersionKey), isFalse);
    });

    test('keeps the original timestamp so FIFO dependency order survives', () {
      // A trip create queued at t0, then an activity create at t1, then the
      // trip is renamed. If the merged create took "now" it would sort after
      // the activity and the server would receive a child before its parent.
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.create, {'title': 'Rome'}, createdAt: t0),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'title': 'Rome 2026'},
        now: tNow,
      );

      expect(result.createdAt, t0);
      expect(result.createdAt.isBefore(t1), isTrue);
    });

    test('successive edits all survive', () {
      var payload = <String, dynamic>{
        'id': 'local-1',
        'title': 'Rome',
        'budget': 100,
      };

      for (final patch in [
        {'title': 'Rome 2026'},
        {'budget': 250},
        {'description': 'Anniversary'},
      ]) {
        final result = coalesceOperation(
          existing: [_op(SyncOp.create, payload)],
          incomingOperation: SyncOp.update,
          incomingPayload: patch,
          now: tNow,
        );
        payload = result.payload!;
      }

      expect(payload, {
        'id': 'local-1',
        'title': 'Rome 2026',
        'budget': 250,
        'description': 'Anniversary',
      });
    });
  });

  group('create + delete', () {
    test('cancels out and sends nothing', () {
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.create, {'title': 'Rome'}),
        ],
        incomingOperation: SyncOp.delete,
        incomingPayload: const {},
        now: tNow,
      );

      expect(result.writesOperation, isFalse);
      expect(result.operation, isNull);
      expect(result.idsToDelete, ['q1']);
    });
  });

  group('update + update', () {
    test('merges both patches instead of dropping the first', () {
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.update, {'title': 'Rome', kBaseVersionKey: 'v1'}),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'budget': 500, kBaseVersionKey: 'v2'},
        now: tNow,
      );

      expect(result.operation, SyncOp.update);
      expect(result.payload!['title'], 'Rome');
      expect(result.payload!['budget'], 500);
    });

    test('preserves the oldest base version', () {
      // The combined patch is still relative to the version the first edit
      // started from, so conflict detection must compare against v1.
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.update, {'title': 'Rome', kBaseVersionKey: 'v1'}),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'budget': 500, kBaseVersionKey: 'v2'},
        now: tNow,
      );

      expect(result.payload![kBaseVersionKey], 'v1');
    });

    test('a later edit of the same field wins', () {
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.update, {'title': 'Rome'}),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'title': 'Milan'},
        now: tNow,
      );

      expect(result.payload!['title'], 'Milan');
    });
  });

  group('update + delete', () {
    test('becomes a delete and discards the pending patch', () {
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.update, {'title': 'Rome'}),
        ],
        incomingOperation: SyncOp.delete,
        incomingPayload: const {},
        now: tNow,
      );

      expect(result.operation, SyncOp.delete);
      expect(result.idsToDelete, ['q1']);
    });
  });

  group('delete + create', () {
    test('resurrects the entity with the new create', () {
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.delete, const {}),
        ],
        incomingOperation: SyncOp.create,
        incomingPayload: {'title': 'Rome again'},
        now: tNow,
      );

      expect(result.operation, SyncOp.create);
      expect(result.payload, {'title': 'Rome again'});
    });
  });

  group('in-flight operations', () {
    test('are never rewritten or deleted', () {
      // Its outcome is unknown; rewriting it could double-apply or lose it.
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.create, {'title': 'Rome'},
              id: 'inflight', status: SyncStatus.inProgress),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'title': 'Rome 2026'},
        now: tNow,
      );

      expect(result.idsToDelete, isEmpty);
      expect(result.operation, SyncOp.update);
      expect(result.createdAt, tNow, reason: 'queues behind the in-flight op');
    });

    test('only pending siblings are merged', () {
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.create, {'title': 'Rome'},
              id: 'inflight', status: SyncStatus.inProgress),
          _op(SyncOp.update, {'budget': 100},
              id: 'pending', createdAt: t1),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'title': 'Milan'},
        now: tNow,
      );

      expect(result.idsToDelete, ['pending']);
      expect(result.payload, {'budget': 100, 'title': 'Milan'});
      expect(result.createdAt, t1);
    });
  });

  group('legacy multi-row queues', () {
    test('folds several pending rows into one operation', () {
      // Queues written before coalescing existed can hold more than one row.
      final result = coalesceOperation(
        existing: [
          _op(SyncOp.create, {'id': 'x', 'title': 'Rome'}, id: 'a'),
          _op(SyncOp.update, {'budget': 100}, id: 'b', createdAt: t1),
        ],
        incomingOperation: SyncOp.update,
        incomingPayload: {'title': 'Milan'},
        now: tNow,
      );

      expect(result.operation, SyncOp.create);
      expect(result.payload, {'id': 'x', 'title': 'Milan', 'budget': 100});
      expect(result.idsToDelete, ['a', 'b']);
      expect(result.createdAt, t0);
    });
  });
}
