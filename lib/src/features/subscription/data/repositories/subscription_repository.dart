import 'dart:convert';

import '../../../../core/database/database_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../models/subscription_model.dart';

/// Repository for subscription API calls - read-cache pattern
class SubscriptionRepository {
  final DioClient _dioClient = DioClient();
  final _db = DatabaseService().database;

  static const String _basePath = '/subscription';

  /// Get current user's subscription status - reads from cache, background refresh
  Future<SubscriptionStatus> getStatus() async {
    final cached = await _db.subscriptionCacheDao.getSubscriptionStatus();

    if (cached != null) {
      final status = SubscriptionStatus.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshStatus();
      }

      return status;
    }

    if (!ConnectivityService().isOnline) {
      // Return a safe default when offline with no cache
      return const SubscriptionStatus(
        tier: SubscriptionTier.free,
        plan: SubscriptionPlan.free,
        isPremium: false,
      );
    }

    return _fetchStatus();
  }

  /// Get current user's usage information - reads from cache, background refresh
  Future<UsageInfo> getUsage() async {
    final cached = await _db.subscriptionCacheDao.getUsageInfo();

    if (cached != null) {
      final usage = UsageInfo.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshUsage();
      }

      return usage;
    }

    if (!ConnectivityService().isOnline) {
      throw 'Usage information is not available offline. Please connect to the internet.';
    }

    return _fetchUsage();
  }

  /// Get subscription limits - reads from cache, background refresh
  Future<SubscriptionLimits> getLimits() async {
    final cached = await _db.subscriptionCacheDao.getLimits();

    if (cached != null) {
      final limits = SubscriptionLimits.fromJson(jsonDecode(cached) as Map<String, dynamic>);

      if (ConnectivityService().isOnline) {
        _refreshLimits();
      }

      return limits;
    }

    if (!ConnectivityService().isOnline) {
      throw 'Subscription limits are not available offline. Please connect to the internet.';
    }

    return _fetchLimits();
  }

  /// Get pricing information - API-only with cache fallback
  Future<PricingInfo> getPricing() async {
    if (!ConnectivityService().isOnline) {
      final cached = await _db.subscriptionCacheDao.get('pricing');
      if (cached != null) {
        return PricingInfo.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      throw 'Pricing information requires an internet connection';
    }

    final response = await _dioClient.get('$_basePath/pricing');
    final pricing = PricingInfo.fromJson(response.data);

    // Cache for future offline access
    await _db.subscriptionCacheDao.set('pricing', jsonEncode(response.data));

    return pricing;
  }

  /// Check if user can access a specific feature
  Future<bool> canAccessFeature(String featureName) async {
    if (!ConnectivityService().isOnline) {
      // Check cached status
      final cached = await _db.subscriptionCacheDao.getSubscriptionStatus();
      if (cached != null) {
        final status = SubscriptionStatus.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        return status.isPremium;
      }
      return false;
    }

    final response = await _dioClient.get('$_basePath/feature/$featureName');
    return response.data['has_access'] as bool;
  }

  /// Check if user has storage space for a file
  Future<StorageCheckResult> checkStorageSpace(int fileSizeBytes) async {
    final response = await _dioClient.get(
      '$_basePath/storage/check',
      queryParameters: {'fileSizeBytes': fileSizeBytes},
    );
    return StorageCheckResult.fromJson(response.data);
  }

  /// Verify and process a purchase with the backend
  Future<bool> verifyPurchase({
    required String productId,
    required String receiptData,
    String? signature,
    required String platform,
  }) async {
    try {
      final response = await _dioClient.post(
        '$_basePath/purchase/verify',
        data: {
          'product_id': productId,
          'receipt_data': receiptData,
          'signature': signature,
          'platform': platform,
        },
      );
      final verified = response.data['verified'] as bool? ?? false;
      if (verified) {
        // Refresh cached status after purchase
        _refreshStatus();
      }
      return verified;
    } catch (e) {
      AppLogger.error('Failed to verify purchase: $e');
      return false;
    }
  }

  /// Restore purchases - syncs with backend
  Future<bool> restorePurchases({
    required String platform,
    required List<String> productIds,
  }) async {
    try {
      final response = await _dioClient.post(
        '$_basePath/purchase/restore',
        data: {
          'platform': platform,
          'product_ids': productIds,
        },
      );
      final restored = response.data['restored'] as bool? ?? false;
      if (restored) {
        _refreshStatus();
      }
      return restored;
    } catch (e) {
      AppLogger.error('Failed to restore purchases: $e');
      return false;
    }
  }

  // --- Private Methods ---

  Future<SubscriptionStatus> _fetchStatus() async {
    final response = await _dioClient.get('$_basePath/status');
    final status = SubscriptionStatus.fromJson(response.data);
    await _db.subscriptionCacheDao.setSubscriptionStatus(jsonEncode(response.data));
    return status;
  }

  void _refreshStatus() async {
    try {
      final response = await _dioClient.get('$_basePath/status');
      await _db.subscriptionCacheDao.setSubscriptionStatus(jsonEncode(response.data));
    } catch (e) {
      AppLogger.warning('Background subscription status refresh failed: $e');
    }
  }

  Future<UsageInfo> _fetchUsage() async {
    final response = await _dioClient.get('$_basePath/usage');
    final usage = UsageInfo.fromJson(response.data);
    await _db.subscriptionCacheDao.setUsageInfo(jsonEncode(response.data));
    return usage;
  }

  void _refreshUsage() async {
    try {
      final response = await _dioClient.get('$_basePath/usage');
      await _db.subscriptionCacheDao.setUsageInfo(jsonEncode(response.data));
    } catch (e) {
      AppLogger.warning('Background usage refresh failed: $e');
    }
  }

  Future<SubscriptionLimits> _fetchLimits() async {
    final response = await _dioClient.get('$_basePath/limits');
    final limits = SubscriptionLimits.fromJson(response.data);
    await _db.subscriptionCacheDao.setLimits(jsonEncode(response.data));
    return limits;
  }

  void _refreshLimits() async {
    try {
      final response = await _dioClient.get('$_basePath/limits');
      await _db.subscriptionCacheDao.setLimits(jsonEncode(response.data));
    } catch (e) {
      AppLogger.warning('Background limits refresh failed: $e');
    }
  }
}

/// Storage check result
class StorageCheckResult {
  final bool hasSpace;
  final int fileSizeBytes;
  final int currentUsedBytes;
  final int limitBytes;
  final int remainingBytes;

  StorageCheckResult({
    required this.hasSpace,
    required this.fileSizeBytes,
    required this.currentUsedBytes,
    required this.limitBytes,
    required this.remainingBytes,
  });

  factory StorageCheckResult.fromJson(Map<String, dynamic> json) {
    return StorageCheckResult(
      hasSpace: json['has_space'] as bool,
      fileSizeBytes: json['file_size_bytes'] as int,
      currentUsedBytes: json['current_used_bytes'] as int,
      limitBytes: json['limit_bytes'] as int,
      remainingBytes: json['remaining_bytes'] as int,
    );
  }
}
