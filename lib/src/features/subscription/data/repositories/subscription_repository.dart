import '../../../../core/network/dio_client.dart';
import '../../../../core/services/logger_service.dart';
import '../models/subscription_model.dart';

/// Repository for subscription API calls
class SubscriptionRepository {
  final DioClient _dioClient = DioClient();

  static const String _basePath = '/api/v1/subscription';

  /// Get current user's subscription status
  Future<SubscriptionStatus> getStatus() async {
    final response = await _dioClient.get('$_basePath/status');
    return SubscriptionStatus.fromJson(response.data);
  }

  /// Get current user's usage information
  Future<UsageInfo> getUsage() async {
    final response = await _dioClient.get('$_basePath/usage');
    return UsageInfo.fromJson(response.data);
  }

  /// Get subscription limits for both tiers
  Future<SubscriptionLimits> getLimits() async {
    final response = await _dioClient.get('$_basePath/limits');
    return SubscriptionLimits.fromJson(response.data);
  }

  /// Get pricing information
  Future<PricingInfo> getPricing() async {
    final response = await _dioClient.get('$_basePath/pricing');
    return PricingInfo.fromJson(response.data);
  }

  /// Check if user can access a specific feature
  Future<bool> canAccessFeature(String featureName) async {
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
      return response.data['verified'] as bool? ?? false;
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
      return response.data['restored'] as bool? ?? false;
    } catch (e) {
      AppLogger.error('Failed to restore purchases: $e');
      return false;
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
