import 'package:drift/drift.dart';

import '../app_database.dart';

part 'subscription_cache_dao.g.dart';

@DriftAccessor(tables: [LocalSubscriptionCache])
class SubscriptionCacheDao extends DatabaseAccessor<AppDatabase> with _$SubscriptionCacheDaoMixin {
  SubscriptionCacheDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(localSubscriptionCache)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) {
    return into(localSubscriptionCache).insertOnConflictUpdate(
      LocalSubscriptionCacheCompanion(
        key: Value(key),
        value: Value(value),
        cachedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<LocalSubscriptionCacheData>> getAll() {
    return select(localSubscriptionCache).get();
  }

  Future<void> clear() {
    return delete(localSubscriptionCache).go();
  }

  // Convenience methods
  Future<String?> getSubscriptionStatus() => get('subscription_status');
  Future<void> setSubscriptionStatus(String json) => set('subscription_status', json);

  Future<String?> getUsageInfo() => get('usage_info');
  Future<void> setUsageInfo(String json) => set('usage_info', json);

  Future<String?> getLimits() => get('subscription_limits');
  Future<void> setLimits(String json) => set('subscription_limits', json);
}
