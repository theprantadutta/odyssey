import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'trip_model.g.dart';

/// Converts budget from various types to double
double? _budgetFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value);
  return null;
}

/// Trip model matching backend schema
@JsonSerializable()
class TripModel extends Equatable {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String title;
  final String? description;
  @JsonKey(name: 'cover_image_url')
  final String? coverImageUrl;
  @JsonKey(name: 'start_date')
  final String startDate;
  @JsonKey(name: 'end_date')
  final String endDate;
  final String status;
  final List<String>? tags;
  @JsonKey(fromJson: _budgetFromJson)
  final double? budget;
  @JsonKey(name: 'display_currency')
  final String displayCurrency;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const TripModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.tags,
    this.budget,
    this.displayCurrency = 'USD',
    required this.createdAt,
    required this.updatedAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) =>
      _$TripModelFromJson(json);

  Map<String, dynamic> toJson() => _$TripModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        coverImageUrl,
        startDate,
        endDate,
        status,
        tags,
        budget,
        displayCurrency,
        createdAt,
        updatedAt,
      ];
}

/// Create/Update trip request
@JsonSerializable(createFactory: false)
class TripRequest {
  final String title;
  final String? description;
  @JsonKey(name: 'cover_image_url')
  final String? coverImageUrl;
  @JsonKey(name: 'start_date')
  final String startDate;
  @JsonKey(name: 'end_date')
  final String endDate;
  final String status;
  final List<String>? tags;
  final double? budget;
  @JsonKey(name: 'display_currency')
  final String? displayCurrency;

  const TripRequest({
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.tags,
    this.budget,
    this.displayCurrency,
  });

  Map<String, dynamic> toJson() => _$TripRequestToJson(this);
}

/// Trips list response (paginated)
@JsonSerializable()
class TripsResponse {
  final List<TripModel> trips;
  final int total;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;

  const TripsResponse({
    required this.trips,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory TripsResponse.fromJson(Map<String, dynamic> json) =>
      _$TripsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TripsResponseToJson(this);
}

/// Trip status enum
enum TripStatus {
  planned,
  ongoing,
  completed;

  String get displayName {
    switch (this) {
      case TripStatus.planned:
        return 'Planned';
      case TripStatus.ongoing:
        return 'Ongoing';
      case TripStatus.completed:
        return 'Completed';
    }
  }
}
