import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/router/task_routes.dart';
import '../../../ads/presentation/widgets/watch_ad_to_unlock_button.dart';
import '../../../settings/presentation/widgets/legal_document_viewer.dart';
import '../mixins/subscription_lifecycle_mixin.dart';
import '../providers/feature_access_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/subscription_provider.dart'
    show SubscriptionState, subscriptionProvider, isPremiumProvider;

/// What Pro is, and how to get it.
///
/// The lime hero carries the pitch; the plans sit underneath as cards. Nothing
/// here invents a price: every card shows the store's own localised figure and
/// only appears when that product actually loaded.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({
    super.key,
    this.featureName,
    this.customTitle,
    this.customDescription,
    this.featureIcon,
    this.unlockableFeature,
  });

  final String? featureName;
  final String? customTitle;
  final String? customDescription;
  final IconData? featureIcon;

  /// When set, free users are offered a "watch an ad to unlock for 24h" option
  /// in addition to upgrading.
  final PremiumFeature? unlockableFeature;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen>
    with WidgetsBindingObserver, SubscriptionLifecycleMixin {
  static const List<(IconData, String, String)> _features = [
    (
      Icons.all_inclusive_rounded,
      'No limits',
      'As many trips, plans, photos and documents as you want.',
    ),
    (
      Icons.map_outlined,
      'The world map',
      'Every trip you have taken, pinned where it happened.',
    ),
    (
      Icons.insights_outlined,
      'The full picture',
      'Statistics and the year in review, all of it.',
    ),
    (
      Icons.group_outlined,
      'Travel together',
      'Let the people you travel with edit the plan, not just read it.',
    ),
    (
      Icons.videocam_outlined,
      'Video memories',
      'Keep the moving ones too, not just the stills.',
    ),
    (
      Icons.block_outlined,
      'No ads',
      'The whole app, uninterrupted.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .trackPaywallShown(featureName: widget.featureName ?? 'unknown'),
    );

    ref.listenManual(purchaseProvider, (previous, next) {
      if (next.successMessage != null && previous?.successMessage == null) {
        _onPurchased();
      }
    });
  }

  void _onPurchased() {
    showOdysseyMessage(context, 'You are on Pro. Everything is unlocked.');
    ref.read(purchaseProvider.notifier).clearSuccess();
    Navigator.of(context).pop(true);
  }

  void _openLegal(String title, String assetPath) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.legalViewer),
        builder: (_) => LegalDocumentViewer(title: title, assetPath: assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final subscription = ref.watch(subscriptionProvider);
    final purchase = ref.watch(purchaseProvider);

    if (purchase.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Safe by construction: PurchaseNotifier only ever stores prose
        // it wrote itself, never the billing client's own text.
        showOdysseyMessage(context, purchase.error!);
        ref.read(purchaseProvider.notifier).clearError();
      });
    }

    return OdysseyScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.contentTop,
          AppSizes.screenPadding,
          AppSizes.scrollBottom,
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: CircleButton(
              glyph: '✕',
              onPressed: () => Navigator.of(context).pop(),
              semanticLabel: 'Close',
            ),
          ),
          const SizedBox(height: AppSizes.space18),

          // The lime hero, as everywhere else the brand makes its case.
          HeroTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const EyebrowLabel(
                  'Odyssey Pro',
                  color: AppColors.onAccentLabel,
                ),
                const SizedBox(height: AppSizes.space14),
                Text(
                  widget.customTitle ??
                      (widget.featureName == null
                          ? 'The whole\njournal.'
                          : '${widget.featureName}\nis part of Pro.'),
                  style: AppTypography.heroTitle.copyWith(
                    fontSize: 34,
                    letterSpacing: -1.36,
                    color: AppColors.onAccent,
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                Text(
                  widget.customDescription ??
                      'Every limit lifted, every screen unlocked, no ads.',
                  style: AppTypography.metaLarge.copyWith(
                    color: AppColors.onAccent2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.space20),

          _buildPlans(subscription, purchase),

          if (widget.unlockableFeature != null) ...[
            const SizedBox(height: AppSizes.space16),
            Center(
              child: WatchAdToUnlockButton(feature: widget.unlockableFeature!),
            ),
          ],

          const SizedBox(height: AppSizes.space26),
          const EyebrowLabel('What you get'),
          const SizedBox(height: AppSizes.space14),
          GroupedCard(
            children: [
              for (var i = 0; i < _features.length; i++)
                _FeatureRow(
                  icon: _features[i].$1,
                  title: _features[i].$2,
                  body: _features[i].$3,
                  circleChip: i.isOdd,
                ),
            ],
          ),

          const SizedBox(height: AppSizes.space20),
          PillButton(
            label: 'Restore a purchase',
            style: PillStyle.outline,
            onPressed: purchase.isPurchasing
                ? null
                : () => ref.read(purchaseProvider.notifier).restorePurchases(),
            padding: const EdgeInsets.symmetric(vertical: AppSizes.space14),
          ),

          const SizedBox(height: AppSizes.space18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegalLink(
                label: 'Terms',
                onTap: () => _openLegal(
                  'Terms & Conditions',
                  'assets/legal/terms.md',
                ),
              ),
              Text(
                ' · ',
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
              ),
              _LegalLink(
                label: 'Privacy',
                onTap: () => _openLegal(
                  'Privacy Policy',
                  'assets/legal/privacy.md',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space10),
          Text(
            'Subscriptions renew automatically until cancelled. Manage or '
            'cancel in your store account.',
            textAlign: TextAlign.center,
            style: AppTypography.badgeDesc.copyWith(color: t.ink3),
          ),
        ],
      ),
    );
  }

  Widget _buildPlans(SubscriptionState subscription, PurchaseState purchase) {
    if (!purchase.isInitialized) {
      return const Column(
        children: [
          Skeleton(width: double.infinity, height: 78, radius: AppSizes.radiusTile),
          SizedBox(height: AppSizes.space10),
          Skeleton(width: double.infinity, height: 78, radius: AppSizes.radiusTile),
        ],
      );
    }

    // StoreKit returned no products. Never render tappable price cards in this
    // state: a card showing a price that fails on tap is exactly what a
    // reviewer reports as "the subscription is not available for purchase
    // using In-App Purchase". Show an honest unavailable state with a retry.
    final hasProducts =
        purchase.yearlyProduct != null ||
        purchase.monthlyProduct != null ||
        purchase.lifetimeProduct != null;

    if (!hasProducts) {
      return OdysseyErrorState(
        message: 'We could not reach the store to load the plans. Check your '
            'connection and try again.',
        onRetry: () => ref.read(purchaseProvider.notifier).retry(),
      );
    }

    final savings = subscription.pricing?.yearlySavingsPercent ?? 30;

    return Column(
      children: [
        // Each card appears only when its store product actually loaded, and
        // shows the store's own localised price — never a hardcoded fallback
        // that might not match what the user would be charged.
        if (purchase.yearlyProduct != null) ...[
          _PlanCard(
            title: 'Yearly',
            price: purchase.yearlyPrice!,
            note: 'Save $savings%',
            recommended: true,
            enabled: !purchase.isPurchasing,
            onTap: () => ref.read(purchaseProvider.notifier).purchaseYearly(),
          ),
          const SizedBox(height: AppSizes.space10),
        ],
        if (purchase.monthlyProduct != null) ...[
          _PlanCard(
            title: 'Monthly',
            price: purchase.monthlyPrice!,
            enabled: !purchase.isPurchasing,
            onTap: () => ref.read(purchaseProvider.notifier).purchaseMonthly(),
          ),
          const SizedBox(height: AppSizes.space10),
        ],
        if (purchase.lifetimeProduct != null)
          _PlanCard(
            title: 'Lifetime',
            price: purchase.lifetimePrice!,
            note: 'Paid once',
            enabled: !purchase.isPurchasing,
            onTap: () => ref.read(purchaseProvider.notifier).purchaseLifetime(),
          ),
      ],
    );
  }
}

/// One plan. The recommended one fills with the action colour; the others are
/// hairlined cards, so the choice reads without a badge shouting about it.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.enabled,
    required this.onTap,
    this.note,
    this.recommended = false,
  });

  final String title;
  final String price;
  final String? note;
  final bool recommended;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final background = recommended ? t.action : t.card;
    final foreground = recommended ? t.onAction : t.ink;
    final secondary = recommended
        ? t.onAction.withValues(alpha: 0.7)
        : t.ink3;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Pressable(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusTile),
        tint: !recommended,
        semanticLabel: '$title, $price',
        child: Container(
          padding: const EdgeInsets.all(AppSizes.space18),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppSizes.radiusTile),
            border: Border.all(
              color: recommended ? Colors.transparent : t.hairline,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardTitleLarge.copyWith(
                        color: foreground,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        note!,
                        style: AppTypography.rowMeta.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Text(
                price,
                style: AppTypography.statSmall.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.circleChip,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool circleChip;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(icon: icon, circle: circleChip),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.rowLabel.copyWith(color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTypography.badgeDesc.copyWith(color: t.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space6,
          vertical: AppSizes.space4,
        ),
        child: Text(
          label,
          style: AppTypography.rowMeta.copyWith(color: t.ink2),
        ),
      ),
    );
  }
}

/// A compact version of the pitch, for interrupting a task rather than
/// replacing the screen.
class PaywallDialog extends StatelessWidget {
  const PaywallDialog({
    super.key,
    this.featureName,
    this.onUpgrade,
    this.unlockableFeature,
  });

  final String? featureName;
  final VoidCallback? onUpgrade;
  final PremiumFeature? unlockableFeature;

  static Future<void> show(
    BuildContext context, {
    String? featureName,
    VoidCallback? onUpgrade,
    PremiumFeature? unlockableFeature,
  }) {
    return showModalBottomSheet<void>(
    // Pushed on the root navigator so the sheet covers the tab bar. The
    // bar belongs to the shell's Scaffold, which sits outside a branch
    // navigator - present it there and the bar paints over the sheet,
    // undimmed, with a dead strip of screen beneath it.
    useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaywallDialog(
        featureName: featureName,
        onUpgrade: onUpgrade,
        unlockableFeature: unlockableFeature,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.space24,
        AppSizes.screenPadding,
        AppSizes.space24,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(t.sheet, t.canvas),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusSheet),
        ),
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EyebrowLabel('Odyssey Pro'),
            const SizedBox(height: AppSizes.space12),
            Text(
              featureName == null
                  ? 'That is part of Pro'
                  : '$featureName is part of Pro',
              style: AppTypography.statSmall.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space10),
            Text(
              'Every limit lifted, every screen unlocked, no ads.',
              style: AppTypography.subtitle.copyWith(color: t.ink2),
            ),
            const SizedBox(height: AppSizes.space20),

            if (unlockableFeature != null) ...[
              Center(child: WatchAdToUnlockButton(feature: unlockableFeature!)),
              const SizedBox(height: AppSizes.space12),
            ],

            PillButton(
              label: 'See Pro',
              onPressed: () {
                Navigator.of(context).pop();
                onUpgrade?.call();
              },
            ),
            const SizedBox(height: AppSizes.space10),
            PillButton(
              label: 'Not now',
              style: PillStyle.outline,
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entry points to the paywall, kept as they were so call sites do not move.
class PaywallUtils {
  /// Shows the full paywall for a feature.
  static Future<void> showPaywall(
    BuildContext context, {
    String? featureName,
    String? customTitle,
    String? customDescription,
    IconData? featureIcon,
    PremiumFeature? unlockableFeature,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => PaywallScreen(
          featureName: featureName,
          customTitle: customTitle,
          customDescription: customDescription,
          featureIcon: featureIcon,
          unlockableFeature: unlockableFeature,
        ),
      ),
    );
  }

  /// Shows the compact version, for interrupting a task.
  static Future<void> showQuickPaywall(
    BuildContext context, {
    String? featureName,
    VoidCallback? onUpgrade,
    PremiumFeature? unlockableFeature,
  }) {
    return PaywallDialog.show(
      context,
      featureName: featureName,
      onUpgrade: onUpgrade,
      unlockableFeature: unlockableFeature,
    );
  }

  /// Returns true when the feature is available, and otherwise offers Pro.
  static Future<bool> checkFeatureAccess(
    BuildContext context,
    WidgetRef ref, {
    required String featureName,
    bool showPaywall = true,
  }) async {
    if (ref.read(isPremiumProvider)) return true;

    if (showPaywall) {
      await PaywallUtils.showQuickPaywall(
        context,
        featureName: featureName,
        onUpgrade: () =>
            PaywallUtils.showPaywall(context, featureName: featureName),
      );
    }
    return false;
  }
}
