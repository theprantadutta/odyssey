import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'statistics_model.g.dart';

@JsonSerializable()
class TripStatistics extends Equatable {
  @JsonKey(name: 'total_trips')
  final int totalTrips;
  @JsonKey(name: 'planned_trips')
  final int plannedTrips;
  @JsonKey(name: 'ongoing_trips')
  final int ongoingTrips;
  @JsonKey(name: 'completed_trips')
  final int completedTrips;
  @JsonKey(name: 'trips_this_year')
  final int tripsThisYear;
  @JsonKey(name: 'trips_by_year')
  final Map<String, int> tripsByYear;
  @JsonKey(name: 'average_trip_duration')
  final double averageTripDuration;

  const TripStatistics({
    required this.totalTrips,
    required this.plannedTrips,
    required this.ongoingTrips,
    required this.completedTrips,
    required this.tripsThisYear,
    required this.tripsByYear,
    required this.averageTripDuration,
  });

  factory TripStatistics.fromJson(Map<String, dynamic> json) =>
      _$TripStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$TripStatisticsToJson(this);

  @override
  List<Object?> get props => [
        totalTrips,
        plannedTrips,
        ongoingTrips,
        completedTrips,
        tripsThisYear,
        tripsByYear,
        averageTripDuration,
      ];
}

@JsonSerializable()
class ActivityStatistics extends Equatable {
  @JsonKey(name: 'total_activities')
  final int totalActivities;
  @JsonKey(name: 'completed_activities')
  final int completedActivities;
  @JsonKey(name: 'activities_by_category')
  final Map<String, int> activitiesByCategory;

  const ActivityStatistics({
    required this.totalActivities,
    required this.completedActivities,
    required this.activitiesByCategory,
  });

  factory ActivityStatistics.fromJson(Map<String, dynamic> json) =>
      _$ActivityStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$ActivityStatisticsToJson(this);

  @override
  List<Object?> get props => [
        totalActivities,
        completedActivities,
        activitiesByCategory,
      ];
}

@JsonSerializable()
class MemoryStatistics extends Equatable {
  @JsonKey(name: 'total_memories')
  final int totalMemories;
  @JsonKey(name: 'memories_this_year')
  final int memoriesThisYear;
  @JsonKey(name: 'memories_by_trip')
  final Map<String, int> memoriesByTrip;

  const MemoryStatistics({
    required this.totalMemories,
    required this.memoriesThisYear,
    required this.memoriesByTrip,
  });

  factory MemoryStatistics.fromJson(Map<String, dynamic> json) =>
      _$MemoryStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryStatisticsToJson(this);

  @override
  List<Object?> get props => [
        totalMemories,
        memoriesThisYear,
        memoriesByTrip,
      ];
}

@JsonSerializable()
class ExpenseStatistics extends Equatable {
  @JsonKey(name: 'total_expenses')
  final int totalExpenses;
  @JsonKey(name: 'total_amount_by_currency')
  final Map<String, double> totalAmountByCurrency;
  @JsonKey(name: 'expenses_by_category')
  final Map<String, double> expensesByCategory;
  @JsonKey(name: 'average_expense')
  final double averageExpense;

  const ExpenseStatistics({
    required this.totalExpenses,
    required this.totalAmountByCurrency,
    required this.expensesByCategory,
    required this.averageExpense,
  });

  factory ExpenseStatistics.fromJson(Map<String, dynamic> json) =>
      _$ExpenseStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$ExpenseStatisticsToJson(this);

  @override
  List<Object?> get props => [
        totalExpenses,
        totalAmountByCurrency,
        expensesByCategory,
        averageExpense,
      ];
}

@JsonSerializable()
class PackingStatistics extends Equatable {
  @JsonKey(name: 'total_packing_items')
  final int totalPackingItems;
  @JsonKey(name: 'packed_items')
  final int packedItems;
  @JsonKey(name: 'packing_completion_rate')
  final double packingCompletionRate;

  const PackingStatistics({
    required this.totalPackingItems,
    required this.packedItems,
    required this.packingCompletionRate,
  });

  factory PackingStatistics.fromJson(Map<String, dynamic> json) =>
      _$PackingStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$PackingStatisticsToJson(this);

  @override
  List<Object?> get props => [
        totalPackingItems,
        packedItems,
        packingCompletionRate,
      ];
}

@JsonSerializable()
class SocialStatistics extends Equatable {
  @JsonKey(name: 'trips_shared')
  final int tripsShared;
  @JsonKey(name: 'trips_shared_with_me')
  final int tripsSharedWithMe;
  @JsonKey(name: 'templates_created')
  final int templatesCreated;
  @JsonKey(name: 'templates_used_by_others')
  final int templatesUsedByOthers;

  const SocialStatistics({
    required this.tripsShared,
    required this.tripsSharedWithMe,
    required this.templatesCreated,
    required this.templatesUsedByOthers,
  });

  factory SocialStatistics.fromJson(Map<String, dynamic> json) =>
      _$SocialStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$SocialStatisticsToJson(this);

  @override
  List<Object?> get props => [
        tripsShared,
        tripsSharedWithMe,
        templatesCreated,
        templatesUsedByOthers,
      ];
}

/// Overall statistics from the backend (flat structure)
@JsonSerializable()
class OverallStatistics extends Equatable {
  @JsonKey(name: 'total_trips')
  final int totalTrips;
  @JsonKey(name: 'completed_trips')
  final int completedTrips;
  @JsonKey(name: 'ongoing_trips')
  final int ongoingTrips;
  @JsonKey(name: 'planned_trips')
  final int plannedTrips;
  @JsonKey(name: 'total_activities')
  final int totalActivities;
  @JsonKey(name: 'total_memories')
  final int totalMemories;
  @JsonKey(name: 'total_expenses')
  final int totalExpenses;
  @JsonKey(name: 'total_expense_amount')
  final double totalExpenseAmount;

  /// The currency [totalExpenseAmount] is expressed in.
  ///
  /// The total used to be a raw sum across every currency, rendered with a
  /// hard-coded dollar sign - so 100 USD and 100 EUR were shown as "$200",
  /// a figure that is not an amount of money in any currency.
  @JsonKey(name: 'reporting_currency')
  final String reportingCurrency;

  /// Every currency's own total, so nothing is hidden by the reporting choice.
  @JsonKey(name: 'expense_totals_by_currency')
  final Map<String, double> expenseTotalsByCurrency;

  /// Expenses left out of [totalExpenseAmount] for want of a conversion.
  @JsonKey(name: 'unconverted_expense_count')
  final int unconvertedExpenseCount;

  /// Whether any trip carries a real destination yet.
  @JsonKey(name: 'destination_data_available')
  final bool destinationDataAvailable;

  /// Days booked on trips that have not started.
  @JsonKey(name: 'planned_days_ahead')
  final int plannedDaysAhead;

  /// The user's distinct trip tags — labels they chose, not places.
  @JsonKey(name: 'trip_tags')
  final List<String> tripTags;
  @JsonKey(name: 'countries_visited')
  final int countriesVisited;
  @JsonKey(name: 'total_days_of_travel')
  final int totalDaysOfTravel;
  @JsonKey(name: 'unique_destinations')
  final List<String> uniqueDestinations;
  @JsonKey(name: 'activities_by_category')
  final Map<String, int> activitiesByCategory;
  @JsonKey(name: 'expenses_by_category')
  final Map<String, double> expensesByCategory;

  const OverallStatistics({
    required this.totalTrips,
    required this.completedTrips,
    required this.ongoingTrips,
    required this.plannedTrips,
    required this.totalActivities,
    required this.totalMemories,
    required this.totalExpenses,
    required this.totalExpenseAmount,
    this.reportingCurrency = 'USD',
    this.expenseTotalsByCurrency = const {},
    this.unconvertedExpenseCount = 0,
    this.destinationDataAvailable = false,
    this.plannedDaysAhead = 0,
    this.tripTags = const [],
    required this.countriesVisited,
    required this.totalDaysOfTravel,
    required this.uniqueDestinations,
    required this.activitiesByCategory,
    required this.expensesByCategory,
  });

  factory OverallStatistics.fromJson(Map<String, dynamic> json) =>
      _$OverallStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$OverallStatisticsToJson(this);

  @override
  List<Object?> get props => [
        totalTrips,
        completedTrips,
        ongoingTrips,
        plannedTrips,
        totalActivities,
        totalMemories,
        totalExpenses,
        totalExpenseAmount,
        countriesVisited,
        totalDaysOfTravel,
        uniqueDestinations,
        activitiesByCategory,
        expensesByCategory,
      ];
}

/// A year's travel, as the server reports it.
///
/// Parsed by hand. The generated parser read a shape nobody sends: it required
/// `total_trips` and `total_days_traveled` where the server sends `trips_count`
/// and `total_days`, so a real payload threw before the screen could render.
///
/// Some of what this class used to promise the server does not compute at all -
/// country and city lists, achievements earned, the longest trip. Those are
/// represented honestly rather than defaulted to zero: [destinationDataAvailable]
/// says whether destination figures mean anything, and the screen is expected to
/// ask before showing them. A zero that looks like a measurement is worse than
/// an absence that looks like one.
class YearInReviewStats extends Equatable {
  final int year;

  /// Trips that ran in this year. The server's `trips_count`.
  final int totalTrips;

  /// Days spent travelling. The server's `total_days`.
  final int totalDaysTraveled;

  final int totalActivities;
  final int totalMemories;

  /// Spending in [reportingCurrency] only.
  final double totalSpent;

  /// The currency [totalSpent] is expressed in.
  final String reportingCurrency;

  /// Every currency's own total, so nothing is hidden by the reporting choice.
  final Map<String, double> totalExpensesByCurrency;

  /// Expenses left out of [totalSpent] for want of a conversion rate.
  final int unconvertedExpenseCount;

  /// Whether any trip carries a real destination yet.
  ///
  /// False means [topDestinations] is empty because nothing has been recorded,
  /// not because the user went nowhere.
  final bool destinationDataAvailable;

  /// Destination names, most visited first. Empty until destinations exist.
  final List<String> topDestinations;

  final String? mostActiveMonth;
  final String? mostUsedExpenseCategory;
  final Map<String, int> tripsByMonth;
  final Map<String, double> expensesByCategory;

  const YearInReviewStats({
    required this.year,
    required this.totalTrips,
    required this.totalDaysTraveled,
    required this.totalActivities,
    required this.totalMemories,
    this.totalSpent = 0,
    this.reportingCurrency = 'USD',
    this.totalExpensesByCurrency = const {},
    this.unconvertedExpenseCount = 0,
    this.destinationDataAvailable = false,
    this.topDestinations = const [],
    this.mostActiveMonth,
    this.mostUsedExpenseCategory,
    this.tripsByMonth = const {},
    this.expensesByCategory = const {},
  });

  factory YearInReviewStats.fromJson(Map<String, dynamic> json) {
    return YearInReviewStats(
      year: (json['year'] as num?)?.toInt() ?? 0,
      totalTrips: (json['trips_count'] as num?)?.toInt() ?? 0,
      totalDaysTraveled: (json['total_days'] as num?)?.toInt() ?? 0,
      totalActivities: (json['activities_count'] as num?)?.toInt() ?? 0,
      totalMemories: (json['memories_count'] as num?)?.toInt() ?? 0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      reportingCurrency: json['reporting_currency'] as String? ?? 'USD',
      totalExpensesByCurrency: _numberMap(json['spend_by_currency']),
      unconvertedExpenseCount:
          (json['unconverted_expense_count'] as num?)?.toInt() ?? 0,
      destinationDataAvailable:
          json['destination_data_available'] as bool? ?? false,
      // Objects on the wire - {destination, trip_count, total_days} - flattened
      // to the names the screen lists.
      topDestinations: ((json['top_destinations'] as List<dynamic>?) ?? const [])
          .map((entry) => entry is Map<String, dynamic>
              ? entry['destination'] as String? ?? ''
              : entry.toString())
          .where((name) => name.isNotEmpty)
          .toList(),
      mostActiveMonth: json['most_visited_month'] as String?,
      mostUsedExpenseCategory: json['most_used_expense_category'] as String?,
      tripsByMonth: ((json['trips_by_month'] as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toInt())),
      expensesByCategory: _numberMap(json['expenses_by_category']),
    );
  }

  static Map<String, double> _numberMap(dynamic raw) =>
      ((raw as Map<String, dynamic>?) ?? const {})
          .map((key, value) => MapEntry(key, (value as num).toDouble()));

  Map<String, dynamic> toJson() => {
        'year': year,
        'trips_count': totalTrips,
        'total_days': totalDaysTraveled,
        'activities_count': totalActivities,
        'memories_count': totalMemories,
        'total_spent': totalSpent,
        'reporting_currency': reportingCurrency,
        'spend_by_currency': totalExpensesByCurrency,
        'unconverted_expense_count': unconvertedExpenseCount,
        'destination_data_available': destinationDataAvailable,
        'top_destinations':
            topDestinations.map((name) => {'destination': name}).toList(),
        'most_visited_month': mostActiveMonth,
        'most_used_expense_category': mostUsedExpenseCategory,
        'trips_by_month': tripsByMonth,
        'expenses_by_category': expensesByCategory,
      };

  @override
  List<Object?> get props => [
        year,
        totalTrips,
        totalDaysTraveled,
        totalActivities,
        totalMemories,
        totalSpent,
        reportingCurrency,
        totalExpensesByCurrency,
        unconvertedExpenseCount,
        destinationDataAvailable,
        topDestinations,
        mostActiveMonth,
        mostUsedExpenseCategory,
        tripsByMonth,
        expensesByCategory,
      ];
}

@JsonSerializable()
class TravelTimelineItem extends Equatable {
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String title;
  final String? destination;
  @JsonKey(name: 'start_date')
  final String startDate;
  @JsonKey(name: 'end_date')
  final String endDate;
  final String status;
  @JsonKey(name: 'cover_image_url')
  final String? coverImageUrl;
  @JsonKey(name: 'activities_count')
  final int activitiesCount;
  @JsonKey(name: 'memories_count')
  final int memoriesCount;

  const TravelTimelineItem({
    required this.tripId,
    required this.title,
    this.destination,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.coverImageUrl,
    required this.activitiesCount,
    required this.memoriesCount,
  });

  factory TravelTimelineItem.fromJson(Map<String, dynamic> json) =>
      _$TravelTimelineItemFromJson(json);

  Map<String, dynamic> toJson() => _$TravelTimelineItemToJson(this);

  @override
  List<Object?> get props => [
        tripId,
        title,
        destination,
        startDate,
        endDate,
        status,
        coverImageUrl,
        activitiesCount,
        memoriesCount,
      ];
}

@JsonSerializable()
class TravelTimeline extends Equatable {
  final List<TravelTimelineItem> items;
  @JsonKey(name: 'total_trips')
  final int totalTrips;

  const TravelTimeline({
    required this.items,
    required this.totalTrips,
  });

  factory TravelTimeline.fromJson(Map<String, dynamic> json) =>
      _$TravelTimelineFromJson(json);

  Map<String, dynamic> toJson() => _$TravelTimelineToJson(this);

  @override
  List<Object?> get props => [items, totalTrips];
}
