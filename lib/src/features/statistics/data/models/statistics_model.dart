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

@JsonSerializable()
class OverallStatistics extends Equatable {
  final TripStatistics trips;
  final ActivityStatistics activities;
  final MemoryStatistics memories;
  final ExpenseStatistics expenses;
  final PackingStatistics packing;
  final SocialStatistics social;
  @JsonKey(name: 'total_days_traveled')
  final int totalDaysTraveled;
  @JsonKey(name: 'member_since')
  final String memberSince;
  @JsonKey(name: 'achievement_points')
  final int achievementPoints;

  const OverallStatistics({
    required this.trips,
    required this.activities,
    required this.memories,
    required this.expenses,
    required this.packing,
    required this.social,
    required this.totalDaysTraveled,
    required this.memberSince,
    required this.achievementPoints,
  });

  factory OverallStatistics.fromJson(Map<String, dynamic> json) =>
      _$OverallStatisticsFromJson(json);

  Map<String, dynamic> toJson() => _$OverallStatisticsToJson(this);

  @override
  List<Object?> get props => [
        trips,
        activities,
        memories,
        expenses,
        packing,
        social,
        totalDaysTraveled,
        memberSince,
        achievementPoints,
      ];
}

@JsonSerializable()
class YearInReviewStats extends Equatable {
  final int year;
  @JsonKey(name: 'total_trips')
  final int totalTrips;
  @JsonKey(name: 'total_days_traveled')
  final int totalDaysTraveled;
  @JsonKey(name: 'countries_visited')
  final List<String> countriesVisited;
  @JsonKey(name: 'cities_visited')
  final List<String> citiesVisited;
  @JsonKey(name: 'total_activities')
  final int totalActivities;
  @JsonKey(name: 'total_memories')
  final int totalMemories;
  @JsonKey(name: 'total_expenses_by_currency')
  final Map<String, double> totalExpensesByCurrency;
  @JsonKey(name: 'top_destinations')
  final List<String> topDestinations;
  @JsonKey(name: 'longest_trip_days')
  final int longestTripDays;
  @JsonKey(name: 'longest_trip_title')
  final String? longestTripTitle;
  @JsonKey(name: 'most_active_month')
  final String? mostActiveMonth;
  @JsonKey(name: 'trips_by_month')
  final Map<String, int> tripsByMonth;
  @JsonKey(name: 'achievements_earned')
  final int achievementsEarned;
  @JsonKey(name: 'new_achievement_points')
  final int newAchievementPoints;

  const YearInReviewStats({
    required this.year,
    required this.totalTrips,
    required this.totalDaysTraveled,
    required this.countriesVisited,
    required this.citiesVisited,
    required this.totalActivities,
    required this.totalMemories,
    required this.totalExpensesByCurrency,
    required this.topDestinations,
    required this.longestTripDays,
    this.longestTripTitle,
    this.mostActiveMonth,
    required this.tripsByMonth,
    required this.achievementsEarned,
    required this.newAchievementPoints,
  });

  factory YearInReviewStats.fromJson(Map<String, dynamic> json) =>
      _$YearInReviewStatsFromJson(json);

  Map<String, dynamic> toJson() => _$YearInReviewStatsToJson(this);

  @override
  List<Object?> get props => [
        year,
        totalTrips,
        totalDaysTraveled,
        countriesVisited,
        citiesVisited,
        totalActivities,
        totalMemories,
        totalExpensesByCurrency,
        topDestinations,
        longestTripDays,
        longestTripTitle,
        mostActiveMonth,
        tripsByMonth,
        achievementsEarned,
        newAchievementPoints,
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
