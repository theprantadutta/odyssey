import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'memory_media_model.dart';

part 'memory_model.g.dart';

/// Memory model matching backend schema
@JsonSerializable()
class MemoryModel extends Equatable {
  final String id;
  @JsonKey(name: 'trip_id')
  final String tripId;

  /// Collection of media items (photos and videos) for this memory
  @JsonKey(name: 'media_items')
  final List<MemoryMediaModel> mediaItems;

  /// Legacy field for backward compatibility. Use mediaItems instead.
  @JsonKey(name: 'photo_url')
  final String? photoUrl;

  /// Optional human-readable location name (e.g., "Eiffel Tower, Paris")
  final String? location;

  /// Optional latitude coordinate
  final double? latitude;

  /// Optional longitude coordinate
  final double? longitude;

  /// Optional caption or notes
  final String? caption;

  /// Optional date and time when the memory was taken
  @JsonKey(name: 'taken_at')
  final String? takenAt;

  @JsonKey(name: 'created_at')
  final String createdAt;

  const MemoryModel({
    required this.id,
    required this.tripId,
    this.mediaItems = const [],
    this.photoUrl,
    this.location,
    this.latitude,
    this.longitude,
    this.caption,
    this.takenAt,
    required this.createdAt,
  });

  factory MemoryModel.fromJson(Map<String, dynamic> json) =>
      _$MemoryModelFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryModelToJson(this);

  /// Check if this memory has any media
  bool get hasMedia => mediaItems.isNotEmpty || (photoUrl?.isNotEmpty ?? false);

  /// Check if this memory has any videos
  bool get hasVideo => mediaItems.any((m) => m.isVideo);

  /// Check if this memory has location data
  bool get hasLocation => latitude != null && longitude != null;

  /// Get the primary media item (first in list or legacy photoUrl)
  MemoryMediaModel? get primaryMedia =>
      mediaItems.isNotEmpty ? mediaItems.first : null;

  /// Get the primary URL for display (first media or legacy photoUrl)
  String? get primaryUrl => primaryMedia?.url ?? photoUrl;

  /// Get the display URL (thumbnail for video, full for photo)
  String? get displayUrl => primaryMedia?.displayUrl ?? photoUrl;

  /// Get media count
  int get mediaCount => mediaItems.isNotEmpty ? mediaItems.length : (photoUrl != null ? 1 : 0);

  /// Check if this memory has a location name
  bool get hasLocationName => location != null && location!.isNotEmpty;

  @override
  List<Object?> get props => [
        id,
        tripId,
        mediaItems,
        photoUrl,
        location,
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
