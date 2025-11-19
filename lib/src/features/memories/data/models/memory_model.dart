import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'memory_model.g.dart';

/// Memory model matching backend schema
@JsonSerializable()
class MemoryModel extends Equatable {
  final String id;
  @JsonKey(name: 'trip_id')
  final String tripId;
  @JsonKey(name: 'photo_url')
  final String photoUrl;
  final String latitude;
  final String longitude;
  final String? caption;
  @JsonKey(name: 'taken_at')
  final String? takenAt;
  @JsonKey(name: 'created_at')
  final String createdAt;

  const MemoryModel({
    required this.id,
    required this.tripId,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    this.caption,
    this.takenAt,
    required this.createdAt,
  });

  factory MemoryModel.fromJson(Map<String, dynamic> json) =>
      _$MemoryModelFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        tripId,
        photoUrl,
        latitude,
        longitude,
        caption,
        takenAt,
        createdAt,
      ];
}

/// Memories list response
@JsonSerializable()
class MemoriesResponse {
  final List<MemoryModel> memories;
  final int total;

  const MemoriesResponse({
    required this.memories,
    required this.total,
  });

  factory MemoriesResponse.fromJson(Map<String, dynamic> json) =>
      _$MemoriesResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MemoriesResponseToJson(this);
}
