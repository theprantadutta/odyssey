import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'default_trips_eligibility.g.dart';

/// Whether this account can still add the sample trips (allowed once per account).
@JsonSerializable()
class DefaultTripsEligibility extends Equatable {
  @JsonKey(name: 'can_add')
  final bool canAdd;

  @JsonKey(name: 'added_at')
  final String? addedAt;

  @JsonKey(name: 'has_existing_trips')
  final bool hasExistingTrips;

  @JsonKey(name: 'has_demo_trips')
  final bool hasDemoTrips;

  const DefaultTripsEligibility({
    required this.canAdd,
    this.addedAt,
    required this.hasExistingTrips,
    required this.hasDemoTrips,
  });

  factory DefaultTripsEligibility.fromJson(Map<String, dynamic> json) =>
      _$DefaultTripsEligibilityFromJson(json);

  Map<String, dynamic> toJson() => _$DefaultTripsEligibilityToJson(this);

  @override
  List<Object?> get props => [canAdd, addedAt, hasExistingTrips, hasDemoTrips];
}
