import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/achievement_model.dart';

/// Opens the detail for one badge.
Future<void> showAchievementDetail({
  required BuildContext context,
  required Achievement achievement,
  UserAchievement? userAchievement,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AchievementDetailSheet(
      achievement: achievement,
      userAchievement: userAchievement,
    ),
  );
}

class _AchievementDetailSheet extends StatelessWidget {
  const _AchievementDetailSheet({
    required this.achievement,
    this.userAchievement,
  });

  final Achievement achievement;
  final UserAchievement? userAchievement;

  static final DateFormat _earnedOn = DateFormat('d MMMM yyyy');

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final earned = userAchievement?.isEarned ?? false;
    final progress = userAchievement?.progress ?? 0;
    final threshold = achievement.threshold;
    final fraction = threshold == 0
        ? (earned ? 1.0 : 0.0)
        : (progress / threshold).clamp(0.0, 1.0);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Earned badges get the lime mark; locked ones get the neutral
            // one, which is the same distinction the grid draws.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: earned
                    ? t.action
                    : (t.isDark
                          ? const Color(0x1FFFFFFF)
                          : const Color(0x1A0A0B0D)),
                borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
              ),
            ),
            const SizedBox(height: AppSizes.space18),

            Text(
              achievement.name,
              style: AppTypography.statSmall.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space10),
            Text(
              achievement.description,
              style: AppTypography.subtitle.copyWith(color: t.ink2),
            ),
            const SizedBox(height: AppSizes.space20),

            if (earned) ...[
              EyebrowLabel('Unlocked', color: t.limeText),
              if (userAchievement?.earnedAt != null) ...[
                const SizedBox(height: AppSizes.space8),
                Text(
                  _earnedOn.format(userAchievement!.earnedAt!),
                  style: AppTypography.rowMeta.copyWith(color: t.ink3),
                ),
              ],
            ] else ...[
              const EyebrowLabel('Progress'),
              const SizedBox(height: AppSizes.space10),
              ProgressTrack(value: fraction),
              const SizedBox(height: AppSizes.space10),
              Text(
                threshold == 0
                    ? 'Not started'
                    : '$progress of $threshold',
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
              ),
            ],

            const SizedBox(height: AppSizes.space20),
            Row(
              children: [
                _MetaBlock(
                  label: 'Points',
                  value: '${achievement.points}',
                ),
                const SizedBox(width: AppSizes.space24),
                _MetaBlock(label: 'Tier', value: achievement.tier),
                const SizedBox(width: AppSizes.space24),
                _MetaBlock(label: 'Category', value: achievement.category),
              ],
            ),
            const SizedBox(height: AppSizes.space24),

            PillButton(
              label: 'Close',
              style: PillStyle.outline,
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        EyebrowLabel(label, tight: true),
        const SizedBox(height: AppSizes.space6),
        Text(
          value,
          style: AppTypography.rowTitle.copyWith(color: t.ink),
        ),
      ],
    );
  }
}
