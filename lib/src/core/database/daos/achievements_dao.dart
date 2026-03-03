import 'package:drift/drift.dart';

import '../app_database.dart';

part 'achievements_dao.g.dart';

@DriftAccessor(tables: [LocalAchievements, LocalUserAchievements])
class AchievementsDao extends DatabaseAccessor<AppDatabase> with _$AchievementsDaoMixin {
  AchievementsDao(super.db);

  // ─── Achievement Definitions (read-only cache) ──────────────────

  Future<List<LocalAchievement>> getAllAchievements() {
    return (select(localAchievements)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<void> upsertAchievement(LocalAchievementsCompanion entry) {
    return into(localAchievements).insertOnConflictUpdate(entry);
  }

  Future<void> upsertAchievementBatch(List<LocalAchievementsCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localAchievements, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  // ─── User Achievements (read-only cache) ────────────────────────

  Future<List<LocalUserAchievement>> getAllUserAchievements() {
    return select(localUserAchievements).get();
  }

  Future<LocalUserAchievement?> getUserAchievementById(String id) {
    return (select(localUserAchievements)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertUserAchievement(LocalUserAchievementsCompanion entry) {
    return into(localUserAchievements).insertOnConflictUpdate(entry);
  }

  Future<void> upsertUserAchievementBatch(List<LocalUserAchievementsCompanion> entries) {
    return batch((b) {
      for (final entry in entries) {
        b.insert(localUserAchievements, entry, onConflict: DoUpdate((_) => entry));
      }
    });
  }

  Future<List<LocalUserAchievement>> getUnseen() {
    return (select(localUserAchievements)
          ..where((t) => t.seen.equals(false) & t.earnedAt.isNotNull()))
        .get();
  }

  Future<void> markSeen(String id) {
    return (update(localUserAchievements)..where((t) => t.id.equals(id)))
        .write(const LocalUserAchievementsCompanion(seen: Value(true)));
  }

  Future<void> clearAll() async {
    await delete(localAchievements).go();
    await delete(localUserAchievements).go();
  }
}
