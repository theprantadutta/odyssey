import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../providers/subscription_provider.dart';
import '../screens/paywall_screen.dart';

/// What Pro is, said once, where somebody might go looking.
///
/// A free account could already reach the paywall - from the subscription row,
/// or by hitting a cap - but nothing ever said what was on the other side of
/// it. This does, in the terms the plan is actually sold in, and it says it in
/// one place. The rest of the app stays quiet: an upsell on every screen is how
/// an app starts to feel like it is selling at you rather than working for you.
///
/// Shown only when the account is **known** to be free, never on `!isPremium` -
/// an entitlement that has not resolved is neither, and a subscriber waiting
/// for theirs must not be asked to buy what they already have.
class ProUpsellCard extends ConsumerWidget {
  const ProUpsellCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isKnownFreeProvider)) return const SizedBox.shrink();

    final t = context.odyssey;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space12),
      child: OdysseyCard(
        radius: AppSizes.radiusPanel,
        padding: const EdgeInsets.all(AppSizes.space18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const EyebrowLabel('Pro'),
            const SizedBox(height: AppSizes.space12),
            Text(
              'More room for\neverything.',
              style: AppTypography.statSmall.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space10),
            Text(
              // Specific, and true of the plan as the server defines it: the
              // per-trip caps come off, storage goes from 1GB to 25, and the
              // three gated screens open.
              'No caps on trips, plans, documents or memories. 25 GB for your '
              'photos. The world map, statistics and your year in review.',
              style: AppTypography.rowMeta.copyWith(color: t.ink3),
            ),
            const SizedBox(height: AppSizes.space18),
            PillButton(
              label: 'See Pro',
              onPressed: () {
                HapticFeedback.lightImpact();
                PaywallUtils.showPaywall(context);
              },
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space14),
            ),
          ],
        ),
      ),
    );
  }
}
