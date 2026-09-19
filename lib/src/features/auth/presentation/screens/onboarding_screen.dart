import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/logger_service.dart';
import '../../../trips/data/repositories/trip_repository.dart';
import '../providers/auth_provider.dart';

/// The one question asked after the first sign-in: start with demo trips, or
/// start empty.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _keepClean = false;
  bool _isLoading = false;

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    var addedDemoTrips = false;

    try {
      if (!_keepClean) {
        AppLogger.action('User chose to add demo trips');
        final created = await TripRepository().createDefaultTrips();
        addedDemoTrips = created != null;
        if (created != null) {
          AppLogger.info('Demo trips created successfully: ${created.length}');
        } else {
          AppLogger.info('Demo trips already added to this account, skipping');
        }
      } else {
        AppLogger.action('User chose to start fresh (no demo trips)');
      }

      await ref
          .read(authProvider.notifier)
          .completeOnboarding(addedDemoTrips: addedDemoTrips);
      AppLogger.lifecycle('Onboarding completed');

      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      AppLogger.error('Onboarding failed', e);
      if (mounted) {
        HapticFeedback.heavyImpact();
        showOdysseyMessage(context, 'That did not work: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return OdysseyScaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.authPadding,
                AppSizes.contentTop,
                AppSizes.authPadding,
                AppSizes.scrollBottom,
              ),
              children: [
                Text(
                  'Start full,\nor empty.',
                  style: AppTypography.screenTitle.copyWith(
                    fontSize: 38,
                    letterSpacing: -1.71,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                Text(
                  'Four finished trips to poke at, or a clean page. Either '
                  'way you can change your mind later.',
                  style: AppTypography.body.copyWith(color: t.ink2),
                ),
                const SizedBox(height: AppSizes.space26),

                _ChoiceCard(
                  eyebrow: 'Recommended',
                  title: 'Show me around',
                  body: 'Adds Paris, Tokyo, Bali and New York, complete with '
                      'plans, packing lists, expenses and photos.',
                  selected: !_keepClean,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _keepClean = false);
                  },
                ),
                const SizedBox(height: AppSizes.space12),
                _ChoiceCard(
                  eyebrow: 'Clean slate',
                  title: 'Start empty',
                  body: 'Nothing but the trip you are about to plan.',
                  selected: _keepClean,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _keepClean = true);
                  },
                ),
              ],
            ),
          ),

          StickyFooter(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.authPadding,
              AppSizes.space14,
              AppSizes.authPadding,
              30,
            ),
            child: PillButton(
              label: _keepClean ? 'Start empty' : 'Add the demo trips',
              style: PillStyle.brand,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _handleContinue,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two choices. Selected fills with lime in both themes, which is
/// the same brand treatment the auth call to action gets.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final titleColor = selected ? AppColors.onAccent : t.ink;
    final bodyColor = selected ? AppColors.onAccent2 : t.ink3;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusTile),
      tint: !selected,
      selected: selected,
      child: AnimatedContainer(
        duration: AppSizes.durationState,
        curve: AppSizes.curveState,
        padding: const EdgeInsets.all(AppSizes.space20),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
          border: Border.all(
            color: selected ? Colors.transparent : t.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            EyebrowLabel(
              eyebrow,
              color: selected ? AppColors.onAccentLabel : t.ink3,
            ),
            const SizedBox(height: AppSizes.space12),
            Text(
              title,
              style: AppTypography.statSmall.copyWith(color: titleColor),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              body,
              style: AppTypography.subtitle.copyWith(color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }
}
