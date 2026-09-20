import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/subscription_model.dart';
import '../mixins/subscription_lifecycle_mixin.dart';
import '../providers/purchase_provider.dart';
import '../providers/subscription_provider.dart';
import 'paywall_screen.dart';

/// Your plan: what you are on, what you have used of it, and how to change it.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with WidgetsBindingObserver, SubscriptionLifecycleMixin {
  static String _bytes(int value) {
    if (value <= 0) return '0 MB';
    if (value < 1024 * 1024) return '${(value / 1024).round()} KB';
    if (value < 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final subscription = ref.watch(subscriptionProvider);
    final purchase = ref.watch(purchaseProvider);

    ref.listen(purchaseProvider, (prev, next) {
      if (next.successMessage != null && prev?.successMessage == null) {
        showOdysseyMessage(context, next.successMessage!);
        ref.read(purchaseProvider.notifier).clearSuccess();
      }
      if (next.error != null && prev?.error == null) {
        showOdysseyMessage(context, next.error!);
        ref.read(purchaseProvider.notifier).clearError();
      }
    });

    final isPremium = subscription.isPremium;
    final usage = subscription.usage;

    return OdysseyScaffold(
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: () => ref.read(subscriptionProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            AppSizes.scrollBottom,
          ),
          children: [
            ScreenHeader(onBack: () => context.pop()),
            const SizedBox(height: AppSizes.space20),
            Text(
              'Your plan',
              style: AppTypography.screenTitle.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space20),

            if (subscription.isLoading && subscription.status == null)
              const Column(
                children: [
                  Skeleton(
                    width: double.infinity,
                    height: 150,
                    radius: AppSizes.radiusHero,
                  ),
                  SizedBox(height: AppSizes.space12),
                  Skeleton.row(),
                ],
              )
            else ...[
              _PlanHero(
                isPremium: isPremium,
                status: subscription.status,
                purchasing: purchase.isPurchasing,
                onUpgrade: () => PaywallUtils.showPaywall(context),
              ),

              if (usage != null) ...[
                const SizedBox(height: AppSizes.space20),
                const EyebrowLabel('What you have used'),
                const SizedBox(height: AppSizes.space14),
                OdysseyCard(
                  radius: AppSizes.radiusTile,
                  padding: const EdgeInsets.all(AppSizes.space18),
                  child: Column(
                    children: [
                      _UsageRow(
                        label: 'Storage',
                        used: usage.storageUsedBytes.toDouble(),
                        limit: usage.storageLimitBytes.toDouble(),
                        format: (value) => _bytes(value.round()),
                      ),
                      const SizedBox(height: AppSizes.space16),
                      _UsageRow(
                        label: 'Active trips',
                        used: usage.activeTripCount.toDouble(),
                        limit: usage.activeTripLimit.toDouble(),
                        format: (value) => value.round().toString(),
                      ),
                      const SizedBox(height: AppSizes.space16),
                      _UsageRow(
                        label: 'Templates',
                        used: usage.templateCount.toDouble(),
                        limit: usage.templateLimit.toDouble(),
                        format: (value) => value.round().toString(),
                      ),
                    ],
                  ),
                ),
              ],

              if (subscription.limits != null) ...[
                const SizedBox(height: AppSizes.space20),
                const EyebrowLabel('Free against Pro'),
                const SizedBox(height: AppSizes.space14),
                _LimitsTable(
                  limits: subscription.limits!,
                  isPremium: isPremium,
                ),
              ],

              if (!isPremium) ...[
                const SizedBox(height: AppSizes.space20),
                PillButton(
                  label: 'Restore a purchase',
                  style: PillStyle.outline,
                  onPressed: purchase.isPurchasing
                      ? null
                      : () => ref
                            .read(purchaseProvider.notifier)
                            .restorePurchases(),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSizes.space14,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The current plan. Pro gets the lime hero; free gets a card with the way up.
class _PlanHero extends StatelessWidget {
  const _PlanHero({
    required this.isPremium,
    required this.status,
    required this.purchasing,
    required this.onUpgrade,
  });

  final bool isPremium;
  final SubscriptionStatus? status;
  final bool purchasing;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    if (isPremium) {
      return HeroTile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const EyebrowLabel(
              'Current plan',
              color: AppColors.onAccentLabel,
            ),
            const SizedBox(height: AppSizes.space14),
            Text(
              'Odyssey Pro',
              style: AppTypography.statSection.copyWith(
                color: AppColors.onAccent,
              ),
            ),
            const SizedBox(height: AppSizes.space10),
            Text(
              status?.expiresAt == null
                  ? 'Yours for good.'
                  : 'Renews ${TripFormat.longDate(status!.expiresAt)}',
              style: AppTypography.metaLarge.copyWith(
                color: AppColors.onAccent2,
              ),
            ),
          ],
        ),
      );
    }

    return OdysseyCard(
      radius: AppSizes.radiusHero,
      padding: const EdgeInsets.all(AppSizes.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const EyebrowLabel('Current plan'),
          const SizedBox(height: AppSizes.space14),
          Text(
            'Free',
            style: AppTypography.statSection.copyWith(color: t.ink),
          ),
          const SizedBox(height: AppSizes.space10),
          Text(
            'Everything works; some of it is capped.',
            style: AppTypography.subtitle.copyWith(color: t.ink2),
          ),
          const SizedBox(height: AppSizes.space18),
          PillButton(
            label: 'See Pro',
            onPressed: purchasing ? null : onUpgrade,
          ),
        ],
      ),
    );
  }
}

/// One usage line: a label, a track, and the real numbers underneath.
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.label,
    required this.used,
    required this.limit,
    required this.format,
  });

  final String label;
  final double used;

  /// Negative means there is no cap. The API says so with -1.
  final double limit;

  /// Renders a raw figure - bytes for storage, a plain count otherwise. The
  /// row formats both numbers itself so the unlimited case is decided in one
  /// place rather than at each call site.
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    // Pro lifts most caps, and the sentinel was going straight to the screen:
    // 'Active trips  3 of -1'. There is nothing to be a fraction of either, so
    // the bar goes too - a track that can never fill says nothing.
    final unlimited = limit < 0;
    final detail = unlimited
        ? '${format(used)} used'
        : '${format(used)} of ${format(limit)}';
    final fraction = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.rowLabel.copyWith(color: t.ink),
              ),
            ),
            Text(
              detail,
              style: AppTypography.rowMeta.copyWith(color: t.ink3),
            ),
          ],
        ),
        if (!unlimited) ...[
          const SizedBox(height: AppSizes.space10),
          ProgressTrack(value: fraction),
        ],
      ],
    );
  }
}

/// Free against Pro, line by line. The user's own tier is picked out so the
/// table says where they stand rather than only what exists.
class _LimitsTable extends StatelessWidget {
  const _LimitsTable({required this.limits, required this.isPremium});

  final SubscriptionLimits limits;
  final bool isPremium;

  static String _value(int raw) => raw < 0 ? 'Unlimited' : '$raw';

  static String _bytes(int value) {
    if (value < 0) return 'Unlimited';
    if (value < 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024)).round()} MB';
    }
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(0)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final rows = <(String, String, String)>[
      ('Active trips', _value(limits.free.activeTrips),
          _value(limits.premium.activeTrips)),
      ('Plans per trip', _value(limits.free.activitiesPerTrip),
          _value(limits.premium.activitiesPerTrip)),
      ('Expenses per trip', _value(limits.free.expensesPerTrip),
          _value(limits.premium.expensesPerTrip)),
      ('Packing items', _value(limits.free.packingItemsPerTrip),
          _value(limits.premium.packingItemsPerTrip)),
      ('Memories per trip', _value(limits.free.memoriesPerTrip),
          _value(limits.premium.memoriesPerTrip)),
      ('Documents per trip', _value(limits.free.documentsPerTrip),
          _value(limits.premium.documentsPerTrip)),
      ('Templates', _value(limits.free.templates),
          _value(limits.premium.templates)),
      ('Storage', _bytes(limits.free.storageBytes),
          _bytes(limits.premium.storageBytes)),
    ];

    return OdysseyCard(
      radius: AppSizes.radiusTile,
      padding: const EdgeInsets.all(AppSizes.space18),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox.shrink()),
              Expanded(
                flex: 2,
                child: Text(
                  'Free',
                  textAlign: TextAlign.end,
                  style: AppTypography.eyebrowTight.copyWith(
                    color: isPremium ? t.ink3 : t.limeText,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'PRO',
                  textAlign: TextAlign.end,
                  style: AppTypography.eyebrowTight.copyWith(
                    color: isPremium ? t.limeText : t.ink3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space14),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.space12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    rows[i].$1,
                    style: AppTypography.rowMeta.copyWith(color: t.ink2),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    rows[i].$2,
                    textAlign: TextAlign.end,
                    style: AppTypography.legend.copyWith(
                      color: isPremium ? t.ink3 : t.ink,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    rows[i].$3,
                    textAlign: TextAlign.end,
                    style: AppTypography.legend.copyWith(
                      color: isPremium ? t.ink : t.ink3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
