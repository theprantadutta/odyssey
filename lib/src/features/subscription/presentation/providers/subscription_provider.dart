import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/services/logger_service.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';

part 'subscription_provider.g.dart';

/// Subscription state
class SubscriptionState {
  final SubscriptionStatus? status;
  final UsageInfo? usage;
  final SubscriptionLimits? limits;
  final PricingInfo? pricing;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.status,
    this.usage,
    this.limits,
    this.pricing,
    this.isLoading = false,
    this.error,
  });

  bool get isPremium => status?.isPremium ?? false;
  SubscriptionTier get tier => status?.tier ?? SubscriptionTier.free;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    UsageInfo? usage,
    SubscriptionLimits? limits,
    PricingInfo? pricing,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      usage: usage ?? this.usage,
      limits: limits ?? this.limits,
      pricing: pricing ?? this.pricing,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Subscription repository provider
@riverpod
SubscriptionRepository subscriptionRepository(Ref ref) {
  return SubscriptionRepository();
}

/// Subscription state notifier provider
@riverpod
class Subscription extends _$Subscription {
  late final SubscriptionRepository _repository;

  @override
  SubscriptionState build() {
    _repository = ref.read(subscriptionRepositoryProvider);

    // Load subscription data after initialization
    Future.microtask(() => refresh());

    return const SubscriptionState(isLoading: true);
  }

  /// Refresh all subscription data
  Future<void> refresh() async {
    AppLogger.info('Refreshing subscription data...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load all data in parallel
      final results = await Future.wait([
        _repository.getStatus(),
        _repository.getUsage(),
        _repository.getLimits(),
        _repository.getPricing(),
      ]);

      state = state.copyWith(
        status: results[0] as SubscriptionStatus,
        usage: results[1] as UsageInfo,
        limits: results[2] as SubscriptionLimits,
        pricing: results[3] as PricingInfo,
        isLoading: false,
      );

      AppLogger.info('Subscription data loaded: ${state.status?.tier}');
    } catch (e) {
      AppLogger.error('Failed to load subscription data: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Refresh just usage info (for after uploads)
  Future<void> refreshUsage() async {
    try {
      final usage = await _repository.getUsage();
      state = state.copyWith(usage: usage);
    } catch (e) {
      AppLogger.error('Failed to refresh usage: $e');
    }
  }

  /// Check if user can access a feature
  Future<bool> canAccessFeature(String featureName) async {
    try {
      return await _repository.canAccessFeature(featureName);
    } catch (e) {
      AppLogger.error('Failed to check feature access: $e');
      // Default to checking local state
      return state.isPremium;
    }
  }

  /// Check if user has storage space
  Future<bool> hasStorageSpace(int fileSizeBytes) async {
    try {
      final result = await _repository.checkStorageSpace(fileSizeBytes);
      return result.hasSpace;
    } catch (e) {
      AppLogger.error('Failed to check storage: $e');
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Simple provider to check if user is premium
@riverpod
bool isPremium(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.isPremium;
}

/// Provider for current tier
@riverpod
SubscriptionTier currentTier(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.tier;
}

/// Provider for usage info
@riverpod
UsageInfo? usageInfo(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.usage;
}

/// Provider for pricing info
@riverpod
PricingInfo? pricingInfo(Ref ref) {
  final subscription = ref.watch(subscriptionProvider);
  return subscription.pricing;
}
