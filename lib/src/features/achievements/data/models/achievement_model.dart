import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'achievement_model.g.dart';

@JsonSerializable()
class Achievement extends Equatable {
  final String id;
  final String type;
  final String name;
  final String description;
  final String icon;
  final String category;
  final int threshold;
  final String tier;
  final int points;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  const Achievement({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.threshold,
    required this.tier,
    required this.points,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) =>
      _$AchievementFromJson(json);

  Map<String, dynamic> toJson() => _$AchievementToJson(this);

  @override
  List<Object?> get props => [
        id,
        type,
        name,
        description,
        icon,
        category,
        threshold,
        tier,
        points,
        isActive,
        sortOrder,
      ];
}

@JsonSerializable()
class UserAchievement extends Equatable {
  final String id;
  @JsonKey(name: 'achievement_id')
  final String achievementId;
  final int progress;
  @JsonKey(name: 'earned_at')
  final DateTime? earnedAt;
  final bool seen;
  final Achievement achievement;

  const UserAchievement({
    required this.id,
    required this.achievementId,
    required this.progress,
    this.earnedAt,
    this.seen = false,
    required this.achievement,
  });

  factory UserAchievement.fromJson(Map<String, dynamic> json) =>
      _$UserAchievementFromJson(json);

  Map<String, dynamic> toJson() => _$UserAchievementToJson(this);

  bool get isEarned => earnedAt != null;

  @override
  List<Object?> get props => [
        id,
        achievementId,
        progress,
        earnedAt,
        seen,
        achievement,
      ];
}

@JsonSerializable()
class UserAchievementsResponse extends Equatable {
  final List<UserAchievement> earned;
  @JsonKey(name: 'in_progress')
  final List<UserAchievement> inProgress;
  final List<Achievement> locked;
  @JsonKey(name: 'total_points')
  final int totalPoints;
  @JsonKey(name: 'total_earned')
  final int totalEarned;

  const UserAchievementsResponse({
    required this.earned,
    required this.inProgress,
    required this.locked,
    required this.totalPoints,
    required this.totalEarned,
  });

  factory UserAchievementsResponse.fromJson(Map<String, dynamic> json) =>
      _$UserAchievementsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$UserAchievementsResponseToJson(this);

  @override
  List<Object?> get props =>
      [earned, inProgress, locked, totalPoints, totalEarned];
}

@JsonSerializable()
class AchievementUnlock extends Equatable {
  @JsonKey(name: 'achievement_id')
  final String achievementId;
  final String type;
  final String name;
  final String description;
  final String icon;
  final String tier;
  final int points;
  @JsonKey(name: 'earned_at')
  final DateTime earnedAt;

  const AchievementUnlock({
    required this.achievementId,
    required this.type,
    required this.name,
    required this.description,
    required this.icon,
    required this.tier,
    required this.points,
    required this.earnedAt,
  });

  factory AchievementUnlock.fromJson(Map<String, dynamic> json) =>
      _$AchievementUnlockFromJson(json);

  Map<String, dynamic> toJson() => _$AchievementUnlockToJson(this);

  @override
  List<Object?> get props =>
      [achievementId, type, name, description, icon, tier, points, earnedAt];
}

@JsonSerializable()
class LeaderboardEntry extends Equatable {
  final int rank;
  final String name;
  @JsonKey(name: 'total_points')
  final int totalPoints;
  @JsonKey(name: 'achievements_earned')
  final int achievementsEarned;
  @JsonKey(name: 'is_current_user')
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.totalPoints,
    required this.achievementsEarned,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);

  Map<String, dynamic> toJson() => _$LeaderboardEntryToJson(this);

  @override
  List<Object?> get props =>
      [rank, name, totalPoints, achievementsEarned, isCurrentUser];
}

@JsonSerializable()
class LeaderboardResponse extends Equatable {
  final List<LeaderboardEntry> entries;
  @JsonKey(name: 'current_user_entry')
  final LeaderboardEntry? currentUserEntry;

  const LeaderboardResponse({
    required this.entries,
    this.currentUserEntry,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LeaderboardResponseToJson(this);

  @override
  List<Object?> get props => [entries, currentUserEntry];
}

// Tier colors and display names
enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum;

  String get displayName {
    switch (this) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.platinum:
        return 'Platinum';
    }
  }

  static AchievementTier fromString(String tier) {
    switch (tier.toLowerCase()) {
      case 'silver':
        return AchievementTier.silver;
      case 'gold':
        return AchievementTier.gold;
      case 'platinum':
        return AchievementTier.platinum;
      default:
        return AchievementTier.bronze;
    }
  }
}

// Achievement categories
enum AchievementCategory {
  trips,
  activities,
  memories,
  packing,
  social,
  budget,
  special;

  String get displayName {
    switch (this) {
      case AchievementCategory.trips:
        return 'Trips';
      case AchievementCategory.activities:
        return 'Activities';
      case AchievementCategory.memories:
        return 'Memories';
      case AchievementCategory.packing:
        return 'Packing';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.budget:
        return 'Budget';
      case AchievementCategory.special:
        return 'Special';
    }
  }

  static AchievementCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'activities':
        return AchievementCategory.activities;
      case 'memories':
        return AchievementCategory.memories;
      case 'packing':
        return AchievementCategory.packing;
      case 'social':
        return AchievementCategory.social;
      case 'budget':
        return AchievementCategory.budget;
      case 'special':
        return AchievementCategory.special;
      default:
        return AchievementCategory.trips;
    }
  }
}
