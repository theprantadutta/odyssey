import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'subscription_model.g.dart';

/// Subscription tier enum matching backend
enum SubscriptionTier {
  @JsonValue('Free')
  free,
  @JsonValue('Premium')
  premium,
}

/// Subscription plan enum matching backend
enum SubscriptionPlan {
  @JsonValue('Free')
  free,
  @JsonValue('Monthly')
  monthly,
  @JsonValue('Yearly')
  yearly,
  @JsonValue('Lifetime')
  lifetime,
}

/// Subscription status response from API
@JsonSerializable()
class SubscriptionStatus extends Equatable {
  final SubscriptionTier tier;
  final SubscriptionPlan plan;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @JsonKey(name: 'is_premium')
  final bool isPremium;

  const SubscriptionStatus({
    required this.tier,
    required this.plan,
    this.expiresAt,
    required this.isPremium,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionStatusFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionStatusToJson(this);

  @override
  List<Object?> get props => [tier, plan, expiresAt, isPremium];
}

/// Usage info response from API
@JsonSerializable()
class UsageInfo extends Equatable {
  final SubscriptionTier tier;
  final SubscriptionPlan plan;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;
  @JsonKey(name: 'storage_used_bytes')
  final int storageUsedBytes;
  @JsonKey(name: 'storage_limit_bytes')
  final int storageLimitBytes;
  @JsonKey(name: 'storage_used_percentage')
  final double storageUsedPercentage;
  @JsonKey(name: 'active_trip_count')
  final int activeTripCount;
  @JsonKey(name: 'active_trip_limit')
  final int activeTripLimit;
  @JsonKey(name: 'template_count')
  final int templateCount;
  @JsonKey(name: 'template_limit')
  final int templateLimit;

  const UsageInfo({
    required this.tier,
    required this.plan,
    this.expiresAt,
    required this.storageUsedBytes,
    required this.storageLimitBytes,
    required this.storageUsedPercentage,
    required this.activeTripCount,
    required this.activeTripLimit,
    required this.templateCount,
    required this.templateLimit,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) =>
      _$UsageInfoFromJson(json);

  Map<String, dynamic> toJson() => _$UsageInfoToJson(this);

  bool get isPremium => tier == SubscriptionTier.premium;
  bool get isUnlimitedTrips => activeTripLimit == -1;
  bool get isUnlimitedTemplates => templateLimit == -1;

  String get formattedStorageUsed {
    if (storageUsedBytes < 1024) return '$storageUsedBytes B';
    if (storageUsedBytes < 1024 * 1024) {
      return '${(storageUsedBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (storageUsedBytes < 1024 * 1024 * 1024) {
      return '${(storageUsedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(storageUsedBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedStorageLimit {
    if (storageLimitBytes < 1024 * 1024 * 1024) {
      return '${(storageLimitBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(storageLimitBytes / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB';
  }

  @override
  List<Object?> get props => [
        tier,
        plan,
        expiresAt,
        storageUsedBytes,
        storageLimitBytes,
        storageUsedPercentage,
        activeTripCount,
        activeTripLimit,
        templateCount,
        templateLimit,
      ];
}

/// Subscription limits from API
@JsonSerializable()
class SubscriptionLimits extends Equatable {
  final TierLimits free;
  final TierLimits premium;

  const SubscriptionLimits({
    required this.free,
    required this.premium,
  });

  factory SubscriptionLimits.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionLimitsFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionLimitsToJson(this);

  @override
  List<Object?> get props => [free, premium];
}

/// Tier limits details
@JsonSerializable()
class TierLimits extends Equatable {
  @JsonKey(name: 'active_trips')
  final int activeTrips;
  @JsonKey(name: 'activities_per_trip')
  final int activitiesPerTrip;
  @JsonKey(name: 'expenses_per_trip')
  final int expensesPerTrip;
  @JsonKey(name: 'packing_items_per_trip')
  final int packingItemsPerTrip;
  @JsonKey(name: 'memories_per_trip')
  final int memoriesPerTrip;
  @JsonKey(name: 'media_per_memory')
  final int mediaPerMemory;
  @JsonKey(name: 'documents_per_trip')
  final int documentsPerTrip;
  @JsonKey(name: 'files_per_document')
  final int filesPerDocument;
  final int templates;
  @JsonKey(name: 'storage_bytes')
  final int storageBytes;
  @JsonKey(name: 'max_file_size_bytes')
  final int maxFileSizeBytes;
  @JsonKey(name: 'allow_video')
  final bool allowVideo;
  @JsonKey(name: 'allow_edit_sharing')
  final bool allowEditSharing;
  @JsonKey(name: 'allow_public_templates')
  final bool allowPublicTemplates;
  @JsonKey(name: 'allow_world_map')
  final bool allowWorldMap;
  @JsonKey(name: 'allow_year_in_review')
  final bool allowYearInReview;
  @JsonKey(name: 'allow_full_statistics')
  final bool allowFullStatistics;
  @JsonKey(name: 'allow_leaderboard')
  final bool allowLeaderboard;
  @JsonKey(name: 'allow_all_achievements')
  final bool allowAllAchievements;
  @JsonKey(name: 'allow_data_export')
  final bool allowDataExport;

  const TierLimits({
    required this.activeTrips,
    required this.activitiesPerTrip,
    required this.expensesPerTrip,
    required this.packingItemsPerTrip,
    required this.memoriesPerTrip,
    required this.mediaPerMemory,
    required this.documentsPerTrip,
    required this.filesPerDocument,
    required this.templates,
    required this.storageBytes,
    required this.maxFileSizeBytes,
    required this.allowVideo,
    required this.allowEditSharing,
    required this.allowPublicTemplates,
    required this.allowWorldMap,
    required this.allowYearInReview,
    required this.allowFullStatistics,
    required this.allowLeaderboard,
    required this.allowAllAchievements,
    required this.allowDataExport,
  });

  factory TierLimits.fromJson(Map<String, dynamic> json) =>
      _$TierLimitsFromJson(json);

  Map<String, dynamic> toJson() => _$TierLimitsToJson(this);

  bool get isUnlimited => activeTrips == -1;

  String get formattedStorage {
    if (storageBytes < 1024 * 1024 * 1024) {
      return '${(storageBytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(storageBytes / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB';
  }

  @override
  List<Object?> get props => [
        activeTrips,
        activitiesPerTrip,
        expensesPerTrip,
        packingItemsPerTrip,
        memoriesPerTrip,
        mediaPerMemory,
        documentsPerTrip,
        filesPerDocument,
        templates,
        storageBytes,
        maxFileSizeBytes,
        allowVideo,
        allowEditSharing,
        allowPublicTemplates,
        allowWorldMap,
        allowYearInReview,
        allowFullStatistics,
        allowLeaderboard,
        allowAllAchievements,
        allowDataExport,
      ];
}

/// Pricing info from API
@JsonSerializable()
class PricingInfo extends Equatable {
  final double monthly;
  final double yearly;
  final double lifetime;

  const PricingInfo({
    required this.monthly,
    required this.yearly,
    required this.lifetime,
  });

  factory PricingInfo.fromJson(Map<String, dynamic> json) =>
      _$PricingInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PricingInfoToJson(this);

  String get formattedMonthly => '\$${monthly.toStringAsFixed(2)}/mo';
  String get formattedYearly => '\$${yearly.toStringAsFixed(2)}/yr';
  String get formattedLifetime => '\$${lifetime.toStringAsFixed(2)}';

  double get yearlyMonthlyEquivalent => yearly / 12;
  String get formattedYearlyMonthly => '\$${yearlyMonthlyEquivalent.toStringAsFixed(2)}/mo';

  int get yearlySavingsPercent => ((1 - (yearly / (monthly * 12))) * 100).round();

  @override
  List<Object?> get props => [monthly, yearly, lifetime];
}
