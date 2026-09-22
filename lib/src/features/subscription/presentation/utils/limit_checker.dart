import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/subscription_model.dart';
import '../providers/entitlement_state.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';

/// Centralized utility for proactive limit checking before creation flows.
/// Shows the paywall and returns false if the user has hit their tier limit.
class LimitChecker {
  /// The caps that apply to this account, or null when they must not be
  /// applied here.
  ///
  /// Three answers, not two. `sub.isPremium` is false for an account whose
  /// entitlement has not resolved yet, so choosing the tier with it handed a
  /// subscriber the free caps during startup - and every caller below turns a
  /// cap into a paywall. A paying customer could be stopped from adding a
  /// sixth photo and asked to buy what they had already bought.
  ///
  /// While the answer is unknown this returns null, which every caller already
  /// reads as 'let the server decide'. That is the honest position: the server
  /// is the authority on entitlement and enforces these caps itself, so the
  /// worst case for a free account at its cap is a rejection a moment later
  /// instead of a paywall a moment sooner. The worst case for the alternative
  /// is billing someone twice.
  static TierLimits? _getTierLimits(WidgetRef ref) {
    final sub = ref.read(subscriptionProvider);
    return switch (sub.entitlement) {
      Entitlement.premium => sub.limits?.premium,
      Entitlement.free => sub.limits?.free,
      Entitlement.unknown => null,
    };
  }

  /// Check if user can create a new trip. Shows paywall if limit hit.
  static Future<bool> canCreateTrip(BuildContext context, WidgetRef ref) async {
    final limits = _getTierLimits(ref);
    // Not loaded, or the entitlement is still unknown. Either way this is
    // not the place to decide - the server enforces the same caps.
    if (limits == null) return true;

    final usage = ref.read(usageInfoProvider);
    final currentCount = usage?.activeTripCount ?? 0;

    return _checkLimit(
      context,
      ref,
      currentCount: currentCount,
      limit: limits.activeTrips,
      featureName: 'Active Trips',
      limitName: 'Active trip',
    );
  }

  /// Check if user can add an activity to a trip.
  static Future<bool> canCreateActivity(
    BuildContext context,
    WidgetRef ref, {
    required int currentCount,
  }) async {
    final limits = _getTierLimits(ref);
    if (limits == null) return true;

    return _checkLimit(
      context,
      ref,
      currentCount: currentCount,
      limit: limits.activitiesPerTrip,
      featureName: 'Activities per Trip',
      limitName: 'Activity',
    );
  }

  /// Check if user can add an expense to a trip.
  static Future<bool> canCreateExpense(
    BuildContext context,
    WidgetRef ref, {
    required int currentCount,
  }) async {
    final limits = _getTierLimits(ref);
    if (limits == null) return true;

    return _checkLimit(
      context,
      ref,
      currentCount: currentCount,
      limit: limits.expensesPerTrip,
      featureName: 'Expenses per Trip',
      limitName: 'Expense',
    );
  }

  /// Check if user can add a packing item to a trip.
  static Future<bool> canCreatePackingItem(
    BuildContext context,
    WidgetRef ref, {
    required int currentCount,
  }) async {
    final limits = _getTierLimits(ref);
    if (limits == null) return true;

    return _checkLimit(
      context,
      ref,
      currentCount: currentCount,
      limit: limits.packingItemsPerTrip,
      featureName: 'Packing Items per Trip',
      limitName: 'Packing item',
    );
  }

  /// Check if user can add a memory to a trip.
  static Future<bool> canCreateMemory(
    BuildContext context,
    WidgetRef ref, {
    required int currentCount,
  }) async {
    final limits = _getTierLimits(ref);
    if (limits == null) return true;

    return _checkLimit(
      context,
      ref,
      currentCount: currentCount,
      limit: limits.memoriesPerTrip,
      featureName: 'Memories per Trip',
      limitName: 'Memory',
    );
  }

  /// Check if user can add a document to a trip.
  static Future<bool> canCreateDocument(
    BuildContext context,
    WidgetRef ref, {
    required int currentCount,
  }) async {
    final limits = _getTierLimits(ref);
    if (limits == null) return true;

    return _checkLimit(
      context,
      ref,
      currentCount: currentCount,
      limit: limits.documentsPerTrip,
      featureName: 'Documents per Trip',
      limitName: 'Document',
    );
  }

  /// Check if user can create a template.
  static Future<bool> canCreateTemplate(
    BuildContext context,
    WidgetRef ref, {
    required int currentCount,
  }) async {
    final limits = _getTierLimits(ref);
    if (limits == null) return true;

    return _checkLimit(
      context,
      ref,
      currentCount: currentCount,
      limit: limits.templates,
      featureName: 'Templates',
      limitName: 'Template',
    );
  }

  /// Get the media-per-memory limit for the current tier.
  /// Returns null if limits aren't loaded yet.
  static int? getMediaPerMemoryLimit(WidgetRef ref) {
    return _getTierLimits(ref)?.mediaPerMemory;
  }

  /// Get the files-per-document limit for the current tier.
  /// Returns null if limits aren't loaded yet.
  static int? getFilesPerDocumentLimit(WidgetRef ref) {
    return _getTierLimits(ref)?.filesPerDocument;
  }

  /// Generic limit check helper.
  static Future<bool> _checkLimit(
    BuildContext context,
    WidgetRef ref, {
    required int currentCount,
    required int limit,
    required String featureName,
    required String limitName,
  }) async {
    // -1 means unlimited
    if (limit == -1) return true;

    // Under the limit
    if (currentCount < limit) return true;

    // At or over the limit — show paywall
    await PaywallUtils.showPaywall(
      context,
      featureName: featureName,
      customTitle: '$limitName limit reached',
      customDescription:
          'You\'ve used $currentCount of $limit. Upgrade to Premium for unlimited access.',
    );

    return false;
  }
}
