import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odyssey/src/core/database/app_database.dart';
import 'package:odyssey/src/core/database/database_service.dart';
import 'package:odyssey/src/features/statistics/data/repositories/statistics_repository.dart';

/// The figures the dashboard actually shows (audit A19).
///
/// The backend handlers were corrected and this path was not, even though it is
/// the one the screen normally uses: it summed raw amounts across currencies,
/// counted holidays booked for next year as days already travelled, skipped
/// open-ended trips, and filtered on a `planning` status the server calls
/// `planned`.
///
/// Driven through the real repository against a real database, because backend
/// unit tests cannot prove anything about what this screen renders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('odyssey_stats_');
    db = AppDatabase.forTesting(
        NativeDatabase(File('${tempDir.path}/odyssey.sqlite')));
    DatabaseService.overrideForTesting(db);
  });

  tearDown(() async {
    DatabaseService.clearOverrideForTesting();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  String iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> seedTrip({
    required String id,
    required String startDate,
    String? endDate,
    String status = 'completed',
    String currency = 'USD',
    List<String> tags = const [],
  }) {
    return db.into(db.localTrips).insert(LocalTripsCompanion.insert(
          id: id,
          userId: 'user-a',
          title: 'Trip $id',
          startDate: startDate,
          endDate: Value(endDate),
          status: status,
          tags: Value('[${tags.map((t) => '"$t"').join(',')}]'),
          displayCurrency: Value(currency),
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ));
  }

  Future<void> seedExpense({
    required String id,
    required String tripId,
    required double amount,
    required String currency,
    double? convertedAmount,
    String? convertedCurrency,
    String category = 'food',
  }) {
    return db.into(db.localExpenses).insert(LocalExpensesCompanion.insert(
          id: id,
          tripId: tripId,
          title: 'Expense $id',
          amount: amount,
          currency: Value(currency),
          convertedAmount: Value(convertedAmount),
          convertedCurrency: Value(convertedCurrency),
          category: category,
          date: '2026-05-02',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ));
  }

  group('spending', () {
    test('two currencies are not added together', () async {
      await seedTrip(id: 't1', startDate: '2026-05-01', endDate: '2026-05-05');
      await seedExpense(id: 'e1', tripId: 't1', amount: 100, currency: 'USD');
      await seedExpense(id: 'e2', tripId: 't1', amount: 100, currency: 'EUR');

      final stats = await StatisticsRepository().getOverallStatistics();

      // 100 USD + 100 EUR used to produce 200 with a hard-coded dollar sign -
      // a figure that is not an amount of money in any currency.
      expect(stats.totalExpenseAmount, 100);
      expect(stats.reportingCurrency, 'USD');
      expect(stats.expenseTotalsByCurrency, {'USD': 100.0, 'EUR': 100.0});
      expect(stats.unconvertedExpenseCount, 1,
          reason: 'an expense left out of the headline figure must be counted, '
              'or the total looks complete when it is partial');
    });

    test('a converted expense counts in the currency it was converted to',
        () async {
      await seedTrip(id: 't1', startDate: '2026-05-01', endDate: '2026-05-05');
      await seedExpense(
        id: 'e1',
        tripId: 't1',
        amount: 90,
        currency: 'EUR',
        convertedAmount: 100,
        convertedCurrency: 'USD',
      );

      final stats = await StatisticsRepository().getOverallStatistics();

      expect(stats.totalExpenseAmount, 100);
      expect(stats.unconvertedExpenseCount, 0);
    });

    test('the reporting currency comes from the trips, not from USD', () async {
      await seedTrip(
          id: 't1', startDate: '2026-05-01', endDate: '2026-05-05',
          currency: 'EUR');
      await seedTrip(
          id: 't2', startDate: '2026-05-01', endDate: '2026-05-05',
          currency: 'EUR');
      await seedExpense(id: 'e1', tripId: 't1', amount: 50, currency: 'EUR');

      final stats = await StatisticsRepository().getOverallStatistics();

      expect(stats.reportingCurrency, 'EUR');
      expect(stats.totalExpenseAmount, 50);
    });
  });

  group('days travelled', () {
    test('a trip booked for next year is not counted as travelled', () async {
      final nextYear = DateTime.now().add(const Duration(days: 200));

      await seedTrip(
        id: 't1',
        startDate: iso(nextYear),
        endDate: iso(nextYear.add(const Duration(days: 6))),
        status: 'planned',
      );

      final stats = await StatisticsRepository().getOverallStatistics();

      expect(stats.totalDaysOfTravel, 0,
          reason: 'a holiday that has not happened is not time spent '
              'travelling');
      expect(stats.plannedDaysAhead, 7);
    });

    test('an open-ended trip still counts the days that have happened',
        () async {
      final started = DateTime.now().subtract(const Duration(days: 3));

      await seedTrip(
        id: 't1',
        startDate: iso(started),
        endDate: null,
        status: 'ongoing',
      );

      final stats = await StatisticsRepository().getOverallStatistics();

      // Skipping undated trips entirely meant an ongoing trip contributed
      // nothing - the days happened whether or not an end date was recorded.
      expect(stats.totalDaysOfTravel, 4);
    });

    test('a single-day trip counts as one day', () async {
      final day = DateTime.now().subtract(const Duration(days: 10));

      await seedTrip(id: 't1', startDate: iso(day), endDate: iso(day));

      final stats = await StatisticsRepository().getOverallStatistics();

      // end - start is zero for a day trip. Elapsed days are inclusive.
      expect(stats.totalDaysOfTravel, 1);
    });

    test('a trip in progress counts only up to today', () async {
      final started = DateTime.now().subtract(const Duration(days: 2));
      final ends = DateTime.now().add(const Duration(days: 5));

      await seedTrip(
          id: 't1', startDate: iso(started), endDate: iso(ends),
          status: 'ongoing');

      final stats = await StatisticsRepository().getOverallStatistics();

      expect(stats.totalDaysOfTravel, 3);
    });
  });

  group('trip counts', () {
    test('planned trips are counted under the status the server sends',
        () async {
      await seedTrip(
        id: 't1',
        startDate: '2027-05-01',
        endDate: '2027-05-05',
        status: 'planned',
      );

      final stats = await StatisticsRepository().getOverallStatistics();

      // The local code looked for 'planning', which the server has never sent,
      // so this count was permanently zero.
      expect(stats.plannedTrips, 1);
    });

    test('tags are reported as tags, not as countries', () async {
      await seedTrip(
        id: 't1',
        startDate: '2026-05-01',
        endDate: '2026-05-05',
        tags: ['beach', 'family'],
      );

      final stats = await StatisticsRepository().getOverallStatistics();

      expect(stats.tripTags, ['beach', 'family']);
      expect(stats.countriesVisited, 0);
      expect(stats.destinationDataAvailable, isFalse,
          reason: 'no destination is recorded anywhere, so a country figure '
              'would be a guess presented as a measurement');
    });
  });
}
