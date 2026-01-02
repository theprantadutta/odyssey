import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'memory_media_model.g.dart';

/// Media type enum for photos and videos
enum MediaType {
  @JsonValue('photo')
  photo,
  @JsonValue('video')
  video,
}

/// Model for a single media item (photo or video) in a memory
@JsonSerializable()
class MemoryMediaModel extends Equatable {
  final String url;
  final String type;
  @JsonKey(name: 'thumbnail_url')
  final String? thumbnailUrl;
  @JsonKey(name: 'file_size_bytes')
  final int? fileSizeBytes;
  @JsonKey(name: 'duration_seconds')
  final int? durationSeconds;
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  const MemoryMediaModel({
    required this.url,
    required this.type,
    this.thumbnailUrl,
    this.fileSizeBytes,
    this.durationSeconds,
    this.sortOrder = 0,
  });

  factory MemoryMediaModel.fromJson(Map<String, dynamic> json) =>
      _$MemoryMediaModelFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryMediaModelToJson(this);

  /// Check if this media item is a video
  bool get isVideo => type.toLowerCase() == 'video';

  /// Check if this media item is a photo
  bool get isPhoto => type.toLowerCase() == 'photo';

  /// Get the display URL (thumbnail for videos, original for photos)
  String get displayUrl => isVideo ? (thumbnailUrl ?? url) : url;

  /// Format duration as mm:ss
  String? get formattedDuration {
    if (durationSeconds == null) return null;
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format file size as human readable string
  String? get formattedFileSize {
    if (fileSizeBytes == null) return null;
    if (fileSizeBytes! < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes! < 1024 * 1024) {
      return '${(fileSizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [
        url,
        type,
        thumbnailUrl,
        fileSizeBytes,
        durationSeconds,
        sortOrder,
      ];
}
