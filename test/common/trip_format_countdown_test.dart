import 'package:flutter_test/flutter_test.dart';

import 'package:odyssey/src/common/utils/trip_format.dart';

void main() {
  final today = DateTime.now();
  DateTime day(int offset) => today.add(Duration(days: offset));

  group('countdown', () {
    test('counts down to a trip that has not started', () {
      expect(TripFormat.countdown(day(28), day(32)), '28 days out');
      expect(TripFormat.countdown(day(1), day(4)), 'Tomorrow');
      expect(TripFormat.countdown(day(0), day(3)), 'Today');
    });

    test('reports progress while the trip is running', () {
      expect(TripFormat.countdown(day(-2), day(3)), 'Day 3 of 6');
    });

    test('a finished trip is completed, not under way', () {
      // dayProgress only answers for a day inside the trip, so everything past
      // the end fell through to the same 'Under way' as a trip in progress -
      // and a trip that ended last week sat on the list claiming to be running.
      expect(TripFormat.countdown(day(-16), day(-9)), 'Completed');
      expect(TripFormat.countdown(day(-2), day(-1)), 'Completed');
    });

    test('the last day of a trip is still the trip', () {
      expect(TripFormat.countdown(day(-3), day(0)), 'Day 4 of 4');
    });

    test('no end date means it is still going', () {
      // Nothing has been passed, so there is nothing to call finished.
      expect(TripFormat.countdown(day(-5), null), 'Under way');
    });

    test('no start date says nothing at all', () {
      expect(TripFormat.countdown(null, day(3)), isNull);
    });
  });
}
