import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'document_model.g.dart';

/// Document model matching backend schema
@JsonSerializable()
class DocumentModel extends Equatable {
  final String id;
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String type;
  final String name;
  @JsonKey(name: 'file_url')
  final String fileUrl;
  @JsonKey(name: 'file_type')
  final String fileType;
  final String? notes;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  const DocumentModel({
    required this.id,
    required this.tripId,
    required this.type,
    required this.name,
    required this.fileUrl,
    required this.fileType,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) =>
      _$DocumentModelFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentModelToJson(this);

  @override
  List<Object?> get props => [
        id,
        tripId,
        type,
        name,
        fileUrl,
        fileType,
        notes,
        createdAt,
        updatedAt,
      ];
}

/// Create document request
@JsonSerializable()
class DocumentRequest {
  @JsonKey(name: 'trip_id')
  final String tripId;
  final String type;
  final String name;
  @JsonKey(name: 'file_url')
  final String fileUrl;
  @JsonKey(name: 'file_type')
  final String fileType;
  final String? notes;

  const DocumentRequest({
    required this.tripId,
    required this.type,
    required this.name,
    required this.fileUrl,
    required this.fileType,
    this.notes,
  });

  Map<String, dynamic> toJson() => _$DocumentRequestToJson(this);
}

/// Documents list response
@JsonSerializable()
class DocumentsResponse {
  final List<DocumentModel> documents;
  final int total;

  const DocumentsResponse({
    required this.documents,
    required this.total,
  });

  factory DocumentsResponse.fromJson(Map<String, dynamic> json) =>
      _$DocumentsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentsResponseToJson(this);
}

/// Documents grouped by type
@JsonSerializable()
class DocumentsByType {
  final String type;
  final List<DocumentModel> documents;
  final int count;

  const DocumentsByType({
    required this.type,
    required this.documents,
    required this.count,
  });

  factory DocumentsByType.fromJson(Map<String, dynamic> json) =>
      _$DocumentsByTypeFromJson(json);

  Map<String, dynamic> toJson() => _$DocumentsByTypeToJson(this);
}

/// Document type enum
enum DocumentType {
  ticket,
  reservation,
  passport,
  visa,
  insurance,
  itinerary,
  other;

  String get displayName {
    switch (this) {
      case DocumentType.ticket:
        return 'Ticket';
      case DocumentType.reservation:
        return 'Reservation';
      case DocumentType.passport:
        return 'Passport';
      case DocumentType.visa:
        return 'Visa';
      case DocumentType.insurance:
        return 'Insurance';
      case DocumentType.itinerary:
        return 'Itinerary';
      case DocumentType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case DocumentType.ticket:
        return '🎫';
      case DocumentType.reservation:
        return '🏨';
      case DocumentType.passport:
        return '🛂';
      case DocumentType.visa:
        return '📋';
      case DocumentType.insurance:
        return '🛡️';
      case DocumentType.itinerary:
        return '📅';
      case DocumentType.other:
        return '📄';
    }
  }

  static DocumentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'ticket':
        return DocumentType.ticket;
      case 'reservation':
        return DocumentType.reservation;
      case 'passport':
        return DocumentType.passport;
      case 'visa':
        return DocumentType.visa;
      case 'insurance':
        return DocumentType.insurance;
      case 'itinerary':
        return DocumentType.itinerary;
      default:
        return DocumentType.other;
    }
  }
}

/// File type enum
enum FileType {
  pdf,
  image,
  other;

  String get displayName {
    switch (this) {
      case FileType.pdf:
        return 'PDF';
      case FileType.image:
        return 'Image';
      case FileType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case FileType.pdf:
        return '📕';
      case FileType.image:
        return '🖼️';
      case FileType.other:
        return '📎';
    }
  }

  static FileType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pdf':
        return FileType.pdf;
      case 'image':
        return FileType.image;
      default:
        return FileType.other;
    }
  }
}
