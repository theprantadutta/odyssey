import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'activity_model.g.dart';

/// Activity model matching backend schema
@JsonSerializable()
class ActivityModel extends Equatable {
  final String id;
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String title;
  final String? description;
  @JsonKey(name: 'scheduled_time')
  final String scheduledTime;
  final String category;
  final String? latitude;
  final String? longitude;
  @JsonKey(name: 'sort_order')
  final int sortOrder;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const ActivityModel({
    required this.id,
    required this.tripId,
    required this.title,
    this.description,
    required this.scheduledTime,
    required this.category,
    this.latitude,
    this.longitude,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) =>
      _$ActivityModelFromJson(json);

  Map<String, dynamic> toJson() => _$ActivityModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        tripId,
        title,
        description,
        scheduledTime,
        category,
        latitude,
        longitude,
        sortOrder,
        createdAt,
        updatedAt,
      ];
}

/// Create/Update activity request
@JsonSerializable()
class ActivityRequest {
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String title;
  final String? description;
  @JsonKey(name: 'scheduled_time')
  final String scheduledTime;
  final String category;
  final String? latitude;
  final String? longitude;

  const ActivityRequest({
    required this.tripId,
    required this.title,
    this.description,
    required this.scheduledTime,
    required this.category,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => _$ActivityRequestToJson(this);
}

/// Activities list response
@JsonSerializable()
class ActivitiesResponse {
  final List<ActivityModel> activities;
  final int total;

  const ActivitiesResponse({
    required this.activities,
    required this.total,
  });

  factory ActivitiesResponse.fromJson(Map<String, dynamic> json) =>
      _$ActivitiesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ActivitiesResponseToJson(this);
}

/// Reorder activities request
@JsonSerializable()
class ReorderRequest {
  @JsonKey(name: 'activity_orders')
  final List<ActivityOrder> activityOrders;

  const ReorderRequest({
    required this.activityOrders,
  });

  Map<String, dynamic> toJson() => _$ReorderRequestToJson(this);
}

@JsonSerializable()
class ActivityOrder {
  final String id;
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  const ActivityOrder({
    required this.id,
    required this.sortOrder,
  });

  factory ActivityOrder.fromJson(Map<String, dynamic> json) =>
      _$ActivityOrderFromJson(json);

  Map<String, dynamic> toJson() => _$ActivityOrderToJson(this);
}

/// Activity category enum
enum ActivityCategory {
  food,
  travel,
  stay,
  explore;

  String get displayName {
    switch (this) {
      case ActivityCategory.food:
        return 'Food';
      case ActivityCategory.travel:
        return 'Travel';
      case ActivityCategory.stay:
        return 'Stay';
      case ActivityCategory.explore:
        return 'Explore';
    }
  }

  String get icon {
    switch (this) {
      case ActivityCategory.food:
        return '🍽️';
      case ActivityCategory.travel:
        return '✈️';
      case ActivityCategory.stay:
        return '🏨';
      case ActivityCategory.explore:
        return '🗺️';
    }
  }
}
