import 'package:flutter/material.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../data/models/achievement_model.dart';
import 'achievement_icons.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool isEarned;
  final int? progress;
  final VoidCallback? onTap;
  final double size;

  /// Off wherever the surrounding layout already names the achievement.
  final bool showLabel;

  /// Off wherever the points are already shown, e.g. next to the tier.
  final bool showPoints;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.isEarned = false,
    this.progress,
    this.onTap,
    this.size = 80,
    this.showLabel = true,
    this.showPoints = true,
  });

  @override
  Widget build(BuildContext context) {
    final tier = AchievementTier.fromString(achievement.tier);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge(context, tier),
          if (showLabel) ...[
            const SizedBox(height: AppSizes.space8),
            SizedBox(
              width: size + 20,
              child: Text(
                achievement.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: isEarned ? FontWeight.w600 : FontWeight.normal,
                      color: isEarned
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, AchievementTier tier) {
    final color = tierColor(tier);
    final colorScheme = Theme.of(context).colorScheme;
    final hasChip = (isEarned && showPoints) || (!isEarned && progress != null);

    return SizedBox(
      // Room for the chip that overhangs the bottom edge, so it is never clipped
      // and never collides with whatever sits underneath.
      height: hasChip ? size + 10 : size,
      width: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Same treatment as the category headers: a soft tint of the accent with
          // the line icon on top. No gradient or drop shadow - nothing else in the
          // app is built that way.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEarned
                  ? color.withValues(alpha: 0.15)
                  : colorScheme.onSurface.withValues(alpha: 0.05),
              border: Border.all(
                color: isEarned
                    ? color.withValues(alpha: 0.45)
                    : colorScheme.onSurface.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                achievementIcon(achievement.icon),
                size: size * 0.44,
                color: isEarned
                    ? color
                    : colorScheme.onSurface.withValues(alpha: 0.28),
              ),
            ),
          ),
          if (!isEarned && progress != null)
            Positioned(bottom: 0, child: _buildProgressChip(context)),
          if (isEarned && showPoints)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '+${achievement.points}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$progress/${achievement.threshold}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final bool isEarned;
  final int? progress;
  final DateTime? earnedAt;
  final VoidCallback? onTap;

  const AchievementCard({
    super.key,
    required this.achievement,
    this.isEarned = false,
    this.progress,
    this.earnedAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tier = AchievementTier.fromString(achievement.tier);
    final color = tierColor(tier);

    // Flat, not a Card: these already sit inside a section card, and a raised card
    // within a card reads as clutter. The tier tint carries the earned state.
    final background = isEarned
        ? color.withValues(alpha: 0.06)
        : colorScheme.onSurface.withValues(alpha: 0.03);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: isEarned
                  ? color.withValues(alpha: 0.25)
                  : colorScheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.all(AppSizes.space12),
          child: Row(
            children: [
              // The row already names the achievement and shows its points, so the
              // badge repeats neither.
              AchievementBadge(
                achievement: achievement,
                isEarned: isEarned,
                progress: progress,
                size: 52,
                showLabel: false,
                showPoints: false,
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isEarned
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.space8),
                        _buildTierChip(context, tier),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space4),
                    Text(
                      achievement.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isEarned && earnedAt != null) ...[
                      const SizedBox(height: AppSizes.space8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 13, color: color),
                          const SizedBox(width: 4),
                          Text(
                            'Earned ${_formatDate(earnedAt!)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ] else if (progress != null) ...[
                      const SizedBox(height: AppSizes.space8),
                      _buildProgressBar(context, tier),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierChip(BuildContext context, AchievementTier tier) {
    final color = tierColor(tier);

    // Tinted rather than filled: a solid chip at the end of every row turned the list
    // into a column of loud pills.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isEarned ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${tier.displayName} · ${achievement.points}pts',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isEarned
              ? color
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, AchievementTier tier) {
    final theme = Theme.of(context);
    final progressPercent = (progress! / achievement.threshold).clamp(0.0, 1.0);
    final color = tierColor(tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$progress / ${achievement.threshold}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPercent,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }
}
