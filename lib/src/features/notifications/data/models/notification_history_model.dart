import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_history_model.g.dart';

@JsonSerializable()
class NotificationHistoryModel extends Equatable {
  final String id;
  final String type;
  final String title;
  final String body;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  final Map<String, String>? data;
  @JsonKey(name: 'is_read')
  final bool isRead;
  @JsonKey(name: 'read_at')
  final DateTime? readAt;
  @JsonKey(name: 'related_trip_id')
  final String? relatedTripId;
  @JsonKey(name: 'related_trip_title')
  final String? relatedTripTitle;
  @JsonKey(name: 'related_user_id')
  final String? relatedUserId;
  @JsonKey(name: 'related_user_name')
  final String? relatedUserName;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const NotificationHistoryModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    required this.isRead,
    this.readAt,
    this.relatedTripId,
    this.relatedTripTitle,
    this.relatedUserId,
    this.relatedUserName,
    required this.createdAt,
  });

  factory NotificationHistoryModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationHistoryModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationHistoryModelToJson(this);

  NotificationHistoryModel copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, String>? data,
    bool? isRead,
    DateTime? readAt,
    String? relatedTripId,
    String? relatedTripTitle,
    String? relatedUserId,
    String? relatedUserName,
    DateTime? createdAt,
  }) {
    return NotificationHistoryModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      relatedTripId: relatedTripId ?? this.relatedTripId,
      relatedTripTitle: relatedTripTitle ?? this.relatedTripTitle,
      relatedUserId: relatedUserId ?? this.relatedUserId,
      relatedUserName: relatedUserName ?? this.relatedUserName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        body,
        imageUrl,
        data,
        isRead,
        readAt,
        relatedTripId,
        relatedTripTitle,
        relatedUserId,
        relatedUserName,
        createdAt,
      ];
}

@JsonSerializable()
class NotificationListResponse {
  final List<NotificationHistoryModel> notifications;
  final int total;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;
  @JsonKey(name: 'total_pages')
  final int totalPages;
  @JsonKey(name: 'unread_count')
  final int unreadCount;
  @JsonKey(name: 'has_next_page')
  final bool hasNextPage;
  @JsonKey(name: 'has_previous_page')
  final bool hasPreviousPage;

  const NotificationListResponse({
    required this.notifications,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.unreadCount,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) =>
      _$NotificationListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationListResponseToJson(this);
}

@JsonSerializable()
class UnreadCountResponse {
  final int count;

  const UnreadCountResponse({required this.count});

  factory UnreadCountResponse.fromJson(Map<String, dynamic> json) =>
      _$UnreadCountResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UnreadCountResponseToJson(this);
}

@JsonSerializable()
class MarkAllReadResponse {
  @JsonKey(name: 'marked_count')
  final int markedCount;

  const MarkAllReadResponse({required this.markedCount});

  factory MarkAllReadResponse.fromJson(Map<String, dynamic> json) =>
      _$MarkAllReadResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MarkAllReadResponseToJson(this);
}
