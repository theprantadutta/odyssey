import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/config/api_config.dart';
import '../models/achievement_model.dart';

class AchievementRepository {
  final DioClient _dioClient = DioClient();

  Future<List<Achievement>> getAllAchievements() async {
    try {
      final response = await _dioClient.get(ApiConfig.achievements);
      return (response.data as List)
          .map((json) => Achievement.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserAchievementsResponse> getMyAchievements() async {
    try {
      final response = await _dioClient.get(ApiConfig.achievementsMe);
      return UserAchievementsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<AchievementUnlock>> checkAchievements() async {
    try {
      final response = await _dioClient.post(ApiConfig.achievementsCheck);
      return (response.data as List)
          .map((json) => AchievementUnlock.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<UserAchievement>> getUnseenAchievements() async {
    try {
      final response = await _dioClient.get(ApiConfig.achievementsUnseen);
      return (response.data as List)
          .map((json) => UserAchievement.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAchievementSeen(String achievementId) async {
    try {
      await _dioClient.post(ApiConfig.achievementSeen(achievementId));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<LeaderboardResponse> getLeaderboard({int limit = 10}) async {
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
