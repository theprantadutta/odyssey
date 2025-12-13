import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/achievement_model.dart';
import '../../data/repositories/achievement_repository.dart';

part 'achievements_provider.g.dart';

/// Achievements state
class AchievementsState {
  final List<UserAchievement> earned;
  final List<UserAchievement> inProgress;
  final List<Achievement> locked;
  final int totalPoints;
  final int totalEarned;
  final bool isLoading;
  final String? error;

  const AchievementsState({
    this.earned = const [],
    this.inProgress = const [],
    this.locked = const [],
    this.totalPoints = 0,
    this.totalEarned = 0,
    this.isLoading = false,
    this.error,
  });

  AchievementsState copyWith({
    List<UserAchievement>? earned,
    List<UserAchievement>? inProgress,
    List<Achievement>? locked,
    int? totalPoints,
    int? totalEarned,
    bool? isLoading,
    String? error,
  }) {
    return AchievementsState(
      earned: earned ?? this.earned,
      inProgress: inProgress ?? this.inProgress,
      locked: locked ?? this.locked,
      totalPoints: totalPoints ?? this.totalPoints,
      totalEarned: totalEarned ?? this.totalEarned,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Achievement repository provider
@riverpod
AchievementRepository achievementRepository(Ref ref) {
  return AchievementRepository();
}

/// Achievements provider
@riverpod
class Achievements extends _$Achievements {
  AchievementRepository get _repository => ref.read(achievementRepositoryProvider);

  @override
  AchievementsState build() {
    Future.microtask(() => _loadAchievements());
    return const AchievementsState();
  }

  Future<void> _loadAchievements() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getMyAchievements();
      state = state.copyWith(
        earned: response.earned,
        inProgress: response.inProgress,
        locked: response.locked,
        totalPoints: response.totalPoints,
        totalEarned: response.totalEarned,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await _loadAchievements();
  }

  Future<List<AchievementUnlock>> checkAndUnlock() async {
    try {
      final unlocked = await _repository.checkAchievements();
      if (unlocked.isNotEmpty) {
        await refresh();
      }
      return unlocked;
    } catch (e) {
      return [];
    }
  }

  Future<void> markSeen(String achievementId) async {
    try {
      await _repository.markAchievementSeen(achievementId);
      await refresh();
    } catch (e) {
      // Silent failure
    }
  }
}

/// Leaderboard state
class LeaderboardState {
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserEntry;
  final bool isLoading;
  final String? error;

  const LeaderboardState({
    this.entries = const [],
    this.currentUserEntry,
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    LeaderboardEntry? currentUserEntry,
    bool? isLoading,
    String? error,
  }) {
    return LeaderboardState(
      entries: entries ?? this.entries,
      currentUserEntry: currentUserEntry ?? this.currentUserEntry,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Leaderboard provider
@riverpod
class Leaderboard extends _$Leaderboard {
  AchievementRepository get _repository => ref.read(achievementRepositoryProvider);

  @override
  LeaderboardState build() {
    Future.microtask(() => _loadLeaderboard());
    return const LeaderboardState();
  }

  Future<void> _loadLeaderboard() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getLeaderboard();
      state = state.copyWith(
        entries: response.entries,
        currentUserEntry: response.currentUserEntry,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async {
    await _loadLeaderboard();
  }
}

/// All achievements provider
@riverpod
Future<List<Achievement>> allAchievements(Ref ref) async {
  final repository = ref.watch(achievementRepositoryProvider);
  return repository.getAllAchievements();
}

/// Unseen achievements provider
@riverpod
Future<List<UserAchievement>> unseenAchievements(Ref ref) async {
  final repository = ref.watch(achievementRepositoryProvider);
  return repository.getUnseenAchievements();
}
