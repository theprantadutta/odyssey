import 'package:dio/dio.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/database/model_converters.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../models/achievement_model.dart';

/// Achievement repository - read-cache pattern
class AchievementRepository {
  final DioClient _dioClient = DioClient();
  final _db = DatabaseService().database;

  /// Get all achievement definitions - reads from local cache, background refresh
  Future<List<Achievement>> getAllAchievements() async {
    final localAchievements = await _db.achievementsDao.getAllAchievements();

    if (localAchievements.isNotEmpty || !ConnectivityService().isOnline) {
      final achievements = localAchievements.map(achievementFromLocal).toList();

      if (ConnectivityService().isOnline) {
        _refreshAllAchievementsFromApi();
      }

      return achievements;
    }

    return _fetchAllAchievementsFromApi();
  }

  /// Get user's achievements - reads from local cache, background refresh
  Future<UserAchievementsResponse> getMyAchievements() async {
    final localUserAchievements = await _db.achievementsDao.getAllUserAchievements();
    final localAchievements = await _db.achievementsDao.getAllAchievements();

    if ((localUserAchievements.isNotEmpty || localAchievements.isNotEmpty) ||
        !ConnectivityService().isOnline) {
      final userAchievements = localUserAchievements.map(userAchievementFromLocal).toList();
      final allAchievements = localAchievements.map(achievementFromLocal).toList();

      // Assemble UserAchievementsResponse from local data
      final earnedIds = <String>{};
      final inProgressIds = <String>{};

      final earned = <UserAchievement>[];
      final inProgress = <UserAchievement>[];

      for (final ua in userAchievements) {
        if (ua.isEarned) {
          earned.add(ua);
          earnedIds.add(ua.achievementId);
        } else {
          inProgress.add(ua);
          inProgressIds.add(ua.achievementId);
        }
      }

      final locked = allAchievements
          .where((a) => !earnedIds.contains(a.id) && !inProgressIds.contains(a.id))
          .toList();

      final totalPoints = earned.fold<int>(0, (sum, ua) => sum + ua.achievement.points);

      if (ConnectivityService().isOnline) {
        _refreshMyAchievementsFromApi();
      }

      return UserAchievementsResponse(
        earned: earned,
        inProgress: inProgress,
        locked: locked,
        totalPoints: totalPoints,
        totalEarned: earned.length,
      );
    }

    return _fetchMyAchievementsFromApi();
  }

  /// Check achievements - API-only
  Future<List<AchievementUnlock>> checkAchievements() async {
    if (!ConnectivityService().isOnline) return [];
    try {
      final response = await _dioClient.post(ApiConfig.achievementsCheck);
      return (response.data as List)
          .map((json) => AchievementUnlock.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get unseen achievements - reads from local cache
  Future<List<UserAchievement>> getUnseenAchievements() async {
    final localUnseen = await _db.achievementsDao.getUnseen();

    if (localUnseen.isNotEmpty || !ConnectivityService().isOnline) {
      return localUnseen.map(userAchievementFromLocal).toList();
    }

    try {
      final response = await _dioClient.get(ApiConfig.achievementsUnseen);
      final unseen = (response.data as List)
          .map((json) => UserAchievement.fromJson(json))
          .toList();

      for (final ua in unseen) {
        await _db.achievementsDao.upsertUserAchievement(userAchievementToLocal(ua));
      }

      return unseen;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Mark achievement as seen - update local immediately, try API in background
  Future<void> markAchievementSeen(String achievementId) async {
    // Find user achievement by achievement ID
    final allLocal = await _db.achievementsDao.getAllUserAchievements();
    for (final ua in allLocal) {
      if (ua.achievementId == achievementId) {
        await _db.achievementsDao.markSeen(ua.id);
        break;
      }
    }

    if (ConnectivityService().isOnline) {
      try {
        await _dioClient.post(ApiConfig.achievementSeen(achievementId));
      } catch (e) {
        AppLogger.warning('Failed to sync achievement seen: $e');
      }
    }
  }

  /// Get leaderboard - API-only
  Future<LeaderboardResponse> getLeaderboard({int limit = 10}) async {
    if (!ConnectivityService().isOnline) {
      return const LeaderboardResponse(entries: []);
    }
    try {
      final response = await _dioClient.get(
        ApiConfig.achievementsLeaderboard,
        queryParameters: {'limit': limit},
      );
      return LeaderboardResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> seedAchievements() async {
    try {
      await _dioClient.post('${ApiConfig.achievements}/seed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // --- Private Methods ---

  Future<List<Achievement>> _fetchAllAchievementsFromApi() async {
    try {
      final response = await _dioClient.get(ApiConfig.achievements);
      final achievements = (response.data as List)
          .map((json) => Achievement.fromJson(json))
          .toList();

      final companions = achievements.map(achievementToLocal).toList();
      await _db.achievementsDao.upsertAchievementBatch(companions);

      return achievements;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshAllAchievementsFromApi() async {
    try {
      final response = await _dioClient.get(ApiConfig.achievements);
      final achievements = (response.data as List)
          .map((json) => Achievement.fromJson(json))
          .toList();
      final companions = achievements.map(achievementToLocal).toList();
      await _db.achievementsDao.upsertAchievementBatch(companions);
    } catch (e) {
      AppLogger.warning('Background achievements refresh failed: $e');
    }
  }

  Future<UserAchievementsResponse> _fetchMyAchievementsFromApi() async {
    try {
      final response = await _dioClient.get(ApiConfig.achievementsMe);
      final userResponse = UserAchievementsResponse.fromJson(response.data);

      // Cache all user achievements
      for (final ua in [...userResponse.earned, ...userResponse.inProgress]) {
        await _db.achievementsDao.upsertUserAchievement(userAchievementToLocal(ua));
      }

      // Cache all achievement definitions from locked list
      for (final a in userResponse.locked) {
        await _db.achievementsDao.upsertAchievement(achievementToLocal(a));
      }

      return userResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  void _refreshMyAchievementsFromApi() async {
    try {
      final response = await _dioClient.get(ApiConfig.achievementsMe);
      final userResponse = UserAchievementsResponse.fromJson(response.data);

      for (final ua in [...userResponse.earned, ...userResponse.inProgress]) {
        await _db.achievementsDao.upsertUserAchievement(userAchievementToLocal(ua));
      }

      for (final a in userResponse.locked) {
        await _db.achievementsDao.upsertAchievement(achievementToLocal(a));
      }
    } catch (e) {
      AppLogger.warning('Background user achievements refresh failed: $e');
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'];
      }
      return 'An error occurred: ${e.response!.statusCode}';
    }
    return e.message ?? 'Network error occurred';
  }
}
