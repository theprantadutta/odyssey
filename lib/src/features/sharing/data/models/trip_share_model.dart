enum SharePermission {
  view,
  edit;

  String get displayName {
    switch (this) {
      case SharePermission.view:
        return 'View Only';
      case SharePermission.edit:
        return 'Can Edit';
    }
  }

  static SharePermission fromString(String value) {
    return SharePermission.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SharePermission.view,
    );
  }
}

enum ShareStatus {
  pending,
  accepted,
  declined;

  String get displayName {
    switch (this) {
      case ShareStatus.pending:
        return 'Pending';
      case ShareStatus.accepted:
        return 'Accepted';
      case ShareStatus.declined:
        return 'Declined';
    }
  }

  static ShareStatus fromString(String value) {
    return ShareStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ShareStatus.pending,
    );
  }
}

class TripShareModel {
  final String id;
  final String tripId;
  final String ownerId;
  final String sharedWithEmail;
  final String? sharedWithUserId;
  final SharePermission permission;
  final String inviteCode;
  final DateTime? inviteExpiresAt;
  final ShareStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  const TripShareModel({
    required this.id,
    required this.tripId,
    required this.ownerId,
    required this.sharedWithEmail,
    this.sharedWithUserId,
    required this.permission,
    required this.inviteCode,
    this.inviteExpiresAt,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  factory TripShareModel.fromJson(Map<String, dynamic> json) {
    return TripShareModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      ownerId: json['owner_id'] as String,
      sharedWithEmail: json['shared_with_email'] as String,
      sharedWithUserId: json['shared_with_user_id'] as String?,
      permission: SharePermission.fromString(json['permission'] as String),
      inviteCode: json['invite_code'] as String,
      inviteExpiresAt: json['invite_expires_at'] != null
          ? DateTime.parse(json['invite_expires_at'] as String)
          : null,
      status: ShareStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'owner_id': ownerId,
      'shared_with_email': sharedWithEmail,
      'shared_with_user_id': sharedWithUserId,
      'permission': permission.name,
      'invite_code': inviteCode,
      'invite_expires_at': inviteExpiresAt?.toIso8601String(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }

  TripShareModel copyWith({
    String? id,
    String? tripId,
    String? ownerId,
    String? sharedWithEmail,
    String? sharedWithUserId,
    SharePermission? permission,
    String? inviteCode,
    DateTime? inviteExpiresAt,
    ShareStatus? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
  }) {
    return TripShareModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      ownerId: ownerId ?? this.ownerId,
      sharedWithEmail: sharedWithEmail ?? this.sharedWithEmail,
      sharedWithUserId: sharedWithUserId ?? this.sharedWithUserId,
      permission: permission ?? this.permission,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteExpiresAt: inviteExpiresAt ?? this.inviteExpiresAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }
}

class TripShareRequest {
  final String email;
  final SharePermission permission;
  final int? expiresInHours;

  const TripShareRequest({
    required this.email,
    required this.permission,
    this.expiresInHours,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'permission': permission.name,
      if (expiresInHours != null) 'expires_in_hours': expiresInHours,
    };
  }
}

class TripSharesResponse {
  final List<TripShareModel> shares;
  final int total;

  const TripSharesResponse({
    required this.shares,
    required this.total,
  });

  factory TripSharesResponse.fromJson(Map<String, dynamic> json) {
    return TripSharesResponse(
      shares: (json['shares'] as List<dynamic>)
          .map((e) => TripShareModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }
}

class InviteDetailsModel {
  final String tripId;
  final String tripTitle;
  final String? tripDescription;
  final String? tripCoverImageUrl;
  final String ownerEmail;
  final SharePermission permission;
  final DateTime? expiresAt;
  final bool isExpired;
  final bool alreadyAccepted;

  const InviteDetailsModel({
    required this.tripId,
    required this.tripTitle,
    this.tripDescription,
    this.tripCoverImageUrl,
    required this.ownerEmail,
    required this.permission,
    this.expiresAt,
    required this.isExpired,
    required this.alreadyAccepted,
  });

  factory InviteDetailsModel.fromJson(Map<String, dynamic> json) {
    return InviteDetailsModel(
      tripId: json['trip_id'] as String,
      tripTitle: json['trip_title'] as String,
      tripDescription: json['trip_description'] as String?,
      tripCoverImageUrl: json['trip_cover_image_url'] as String?,
      ownerEmail: json['owner_email'] as String,
      permission: SharePermission.fromString(json['permission'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isExpired: json['is_expired'] as bool,
      alreadyAccepted: json['already_accepted'] as bool,
    );
  }
}

class SharedTripInfo {
  final String tripId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final DateTime startDate;
  final DateTime? endDate;
  final String status;
  final String ownerEmail;
  final SharePermission permission;
  final DateTime sharedAt;

  const SharedTripInfo({
    required this.tripId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.ownerEmail,
    required this.permission,
    required this.sharedAt,
  });

  factory SharedTripInfo.fromJson(Map<String, dynamic> json) {
    return SharedTripInfo(
      tripId: json['trip_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      status: json['status'] as String,
      ownerEmail: json['owner_email'] as String,
      permission: SharePermission.fromString(json['permission'] as String),
      sharedAt: DateTime.parse(json['shared_at'] as String),
    );
  }
}

class SharedTripsResponse {
  final List<SharedTripInfo> trips;
  final int total;

  const SharedTripsResponse({
    required this.trips,
    required this.total,
  });

  factory SharedTripsResponse.fromJson(Map<String, dynamic> json) {
    return SharedTripsResponse(
      trips: (json['trips'] as List<dynamic>)
          .map((e) => SharedTripInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );
  }
}

class AcceptInviteResponse {
  final String message;
  final String tripId;
  final String tripTitle;

  const AcceptInviteResponse({
    required this.message,
    required this.tripId,
    required this.tripTitle,
  });

  factory AcceptInviteResponse.fromJson(Map<String, dynamic> json) {
    return AcceptInviteResponse(
      message: json['message'] as String,
      tripId: json['trip_id'] as String,
      tripTitle: json['trip_title'] as String,
    );
  }
}
