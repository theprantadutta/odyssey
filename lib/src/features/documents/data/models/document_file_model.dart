import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'document_file_model.g.dart';

/// Model for a file within a document
/// Stored as JSONB in the database
@JsonSerializable()
class DocumentFileModel extends Equatable {
  /// URL to the file
  final String url;

  /// Original file name
  @JsonKey(name: 'file_name')
  final String fileName;

  /// MIME type of the file
  @JsonKey(name: 'mime_type')
  final String? mimeType;

  /// File size in bytes
  @JsonKey(name: 'file_size_bytes')
  final int? fileSizeBytes;

  /// Order in the document's file list
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  const DocumentFileModel({
    required this.url,
    required this.fileName,
    this.mimeType,
    this.fileSizeBytes,
    this.sortOrder = 0,
  });

  factory DocumentFileModel.fromJson(Map<String, dynamic> json) =>
      _$DocumentFileModelFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentFileModelToJson(this);

  /// Check if this file is a PDF
  bool get isPdf {
    if (mimeType != null) {
      return mimeType!.contains('pdf');
    }
    return fileName.toLowerCase().endsWith('.pdf');
  }

  /// Check if this file is an image
  bool get isImage {
    if (mimeType != null) {
      return mimeType!.startsWith('image/');
    }
    final lowerName = fileName.toLowerCase();
    return lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp');
  }

  /// Get a human-readable file size
  String get formattedSize {
    if (fileSizeBytes == null) return '';
    final bytes = fileSizeBytes!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get the file extension
  String get extension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  @override
  List<Object?> get props => [url, fileName, mimeType, fileSizeBytes, sortOrder];
}
