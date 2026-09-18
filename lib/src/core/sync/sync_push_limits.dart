/// How much the server will accept in one `POST /sync/push`, and how to split a
/// queue so it never has to refuse one.
///
/// The numbers are the server's, not the client's: they are decided in
/// `SyncPushLimits` in the backend and mirrored here. They have to be the same
/// numbers, because the contract this file exists to keep is that the client
/// never builds a batch the server will reject - a rejection is not something a
/// retry can fix, so it would stall the queue rather than delay it.
library;

import 'dart:convert';

/// The most operations one push may carry.
///
/// Sized on the backend from a fortnight offline with a trip fully planned:
/// activities and expenses day by day, a packing list applied in one tap,
/// documents, memory captions. That comes to a little under this, so the common
/// heavy case is one request rather than a stutter of chunks.
const int kMaxOperationsPerBatch = 500;

/// The most bytes one push body may weigh.
///
/// [kMaxOperationsPerBatch] multiplied by the four-kibibyte allowance the server
/// assumes each operation needs. An ordinary change is a few hundred bytes; the
/// headroom is for the entities carrying free text.
const int kMaxPushBodyBytes = kMaxOperationsPerBatch * 4 * 1024;

/// What `{"changes":[]}` costs before a single operation is in it.
const int _envelopeBytes = 14;

/// The encoded size of one change, as the request body will carry it.
///
/// Measured in UTF-8 bytes rather than string length. `jsonEncode` leaves
/// non-ASCII characters alone, so a trip named in Japanese is three bytes a
/// character on the wire and one character to `String.length` - and a batch
/// measured the second way would be three times the size the server sees.
int encodedChangeBytes(Map<String, dynamic> change) =>
    utf8.encode(jsonEncode(change)).length;

/// Whether an operation of [encodedBytes] is too large to be pushed at all.
///
/// Not "too large for the batch being filled" - too large for any batch. A
/// request carrying nothing but this operation is the smallest one that could
/// carry it, and it is still over [maxBytes], so the server would refuse it with
/// 413 however often it were sent. Chunking cannot help, and a retry cannot
/// either: 413 is a verdict on the body, not on the moment.
///
/// The caller has to take such an operation out of the queue rather than send
/// it. Leaving it in is what turns one unsendable change into a queue that never
/// drains again - the flush stops at the refusal, and every operation behind it
/// waits for a request that can never succeed.
///
/// Measured the way [planPushBatches] measures: the envelope, the element, and
/// the one byte of punctuation it sits behind.
bool exceedsPushBodyLimit(int encodedBytes, {int maxBytes = kMaxPushBodyBytes}) =>
    _envelopeBytes + encodedBytes + 1 > maxBytes;

/// Splits [operations] into batches the server will accept, in queue order.
///
/// Order is the whole point. The queue is ordered by `SyncQueue.sequence`, which
/// exists so a parent create is read before the child that depends on it;
/// splitting the list in place preserves that, so a parent is always in an
/// earlier batch than its child or in the same one. Reordering to pack batches
/// more tightly would break it, which is why nothing here sorts.
///
/// [encodedBytes] gives the wire size of an operation. An operation that on its
/// own exceeds [maxBytes] still gets a batch - alone, which is the smallest
/// request that can carry it. Holding it back here instead would block every
/// operation queued behind it, and no amount of chunking makes a single
/// over-sized operation smaller.
///
/// That batch is nonetheless one the server refuses, so an operation this size
/// must never reach here: the caller screens it out with [exceedsPushBodyLimit]
/// and sets it aside first. The behaviour is kept rather than turned into an
/// error because a lone over-sized operation must not be able to silence the
/// rest of the queue even if a caller forgets - it is sent, refused once, and
/// dealt with, instead of stopping the plan.
List<List<T>> planPushBatches<T>(
  List<T> operations,
  int Function(T) encodedBytes, {
  int maxOperations = kMaxOperationsPerBatch,
  int maxBytes = kMaxPushBodyBytes,
}) {
  if (operations.isEmpty) return const [];

  final batches = <List<T>>[];
  var current = <T>[];
  var currentBytes = _envelopeBytes;

  for (final operation in operations) {
    // One byte for the comma or bracket this element sits behind, so the
    // measurement is of the body rather than of the elements in it.
    final cost = encodedBytes(operation) + 1;

    final wouldOverflow =
        current.length >= maxOperations || currentBytes + cost > maxBytes;

    if (wouldOverflow && current.isNotEmpty) {
      batches.add(current);
      current = <T>[];
      currentBytes = _envelopeBytes;
    }

    current.add(operation);
    currentBytes += cost;
  }

  if (current.isNotEmpty) batches.add(current);
  return batches;
}
