import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/features/trips/data/repositories/trip_date_filter.dart';

/// Local date filtering must answer what the server answers.
///
/// The server compares a trip's `StartDate` as a `DateOnly`, inclusive at both
/// ends. The local filter did not implement date bounds at all, so they worked
/// against a fresh API response and stopped working the moment the list came
/// from the local database — which is every offline use, and most online ones,
/// since the repository reads local rows first.
void main() {
  group('inclusive bounds, matching the server', () {
    test('a trip inside the range matches', () {
      expect(
        matchesStartDateRange(
          '2026-06-15',
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
        ),
        isTrue,
      );
    });

    test('a trip on the lower bound matches', () {
      // The server uses `>=`. An exclusive bound here would drop a trip the
      // server returns, which is the parity failure this is about.
      expect(
        matchesStartDateRange('2026-06-01', from: DateTime(2026, 6, 1)),
        isTrue,
      );
    });

    test('a trip on the upper bound matches', () {
      // The server uses `<=`.
      expect(
        matchesStartDateRange('2026-06-30', to: DateTime(2026, 6, 30)),
        isTrue,
      );
    });

    test('a trip one day before the lower bound does not match', () {
      expect(
        matchesStartDateRange('2026-05-31', from: DateTime(2026, 6, 1)),
        isFalse,
      );
    });

    test('a trip one day after the upper bound does not match', () {
      expect(
        matchesStartDateRange('2026-07-01', to: DateTime(2026, 6, 30)),
        isFalse,
      );
    });

    test('a single-day range matches only that day', () {
      final bound = DateTime(2026, 6, 15);

      expect(matchesStartDateRange('2026-06-15', from: bound, to: bound), isTrue);
      expect(matchesStartDateRange('2026-06-14', from: bound, to: bound), isFalse);
      expect(matchesStartDateRange('2026-06-16', from: bound, to: bound), isFalse);
    });
  });

  group('time of day is not part of the comparison', () {
    test('a timestamp late on the upper-bound day still matches', () {
      // The server compares DateOnly, so the hour cannot decide this. Comparing
      // full timestamps would drop an evening start against a midnight bound -
      // the classic off-by-one-day the server does not have.
      expect(
        matchesStartDateRange(
          '2026-06-30T23:59:59',
          to: DateTime(2026, 6, 30),
        ),
        isTrue,
      );
    });

    test('a timestamp early on the lower-bound day still matches', () {
      expect(
        matchesStartDateRange(
          '2026-06-01T00:00:01',
          from: DateTime(2026, 6, 1),
        ),
        isTrue,
      );
    });

    test('a bound carrying a time is reduced to its day', () {
      // The filter UI can hand over a DateTime with the current time attached.
      expect(
        matchesStartDateRange(
          '2026-06-01',
          from: DateTime(2026, 6, 1, 17, 30),
        ),
        isTrue,
      );
    });
  });

  group('open-ended and absent bounds', () {
    test('no bounds match everything', () {
      expect(matchesStartDateRange('2020-01-01'), isTrue);
      expect(matchesStartDateRange('2099-12-31'), isTrue);
    });

    test('only a lower bound leaves the future open', () {
      expect(
        matchesStartDateRange('2099-12-31', from: DateTime(2026, 1, 1)),
        isTrue,
      );
    });

    test('only an upper bound leaves the past open', () {
      expect(
        matchesStartDateRange('1999-01-01', to: DateTime(2026, 1, 1)),
        isTrue,
      );
    });
  });

  group('unparseable dates', () {
    test('a trip with an unreadable start date is kept', () {
      // Kept, not dropped. A filter that narrows a list should not also lose
      // rows: showing one trip more than asked for is recoverable, a trip that
      // silently vanishes from every filtered view is not.
      expect(
        matchesStartDateRange(
          'not a date',
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
        ),
        isTrue,
      );
    });

    test('an empty start date is kept', () {
      expect(matchesStartDateRange('', from: DateTime(2026, 6, 1)), isTrue);
    });
  });

  group('day reduction', () {
    test('a UTC timestamp is read in local time', () {
      final day = startDayOf('2026-06-15T12:00:00Z');

      expect(day, isNotNull);

      // Whatever the zone, it is midnight of some calendar day - never a
      // timestamp that could compare unequal to an identical date.
      expect(day!.hour, 0);
      expect(day.minute, 0);
      expect(day.second, 0);
    });

    test('a bare date reduces to itself', () {
      expect(startDayOf('2026-06-15'), DateTime(2026, 6, 15));
    });

    test('an unparseable value reduces to null', () {
      expect(startDayOf('nonsense'), isNull);
    });
  });
}
