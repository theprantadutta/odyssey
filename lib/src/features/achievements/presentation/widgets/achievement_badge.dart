import 'package:flutter/material.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../data/models/achievement_model.dart';

class AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool isEarned;
  final int? progress;
  final VoidCallback? onTap;
  final double size;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.isEarned = false,
    this.progress,
    this.onTap,
    this.size = 80,
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
          const SizedBox(height: AppSizes.space4),
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
                            .withOpacity(0.5),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, AchievementTier tier) {
    final tierColors = _getTierColors(tier);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isEarned
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: tierColors,
              )
            : null,
        color: isEarned ? null : Colors.grey.shade300,
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: tierColors[0].withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
        border: Border.all(
          color: isEarned ? tierColors[0] : Colors.grey.shade400,
          width: 3,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Icon
          Text(
            achievement.icon,
            style: TextStyle(
              fontSize: size * 0.4,
              color: isEarned ? null : Colors.grey.shade400,
            ),
          ),
          // Progress indicator (if in progress)
          if (!isEarned && progress != null)
            Positioned(
              bottom: 4,
              child: _buildProgressIndicator(context),
            ),
          // Points badge (if earned)
          if (isEarned)
            Positioned(
              bottom: -2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tierColors[0],
                  borderRadius: BorderRadius.circular(10),
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

  Widget _buildProgressIndicator(BuildContext context) {
    final progressPercent = (progress! / achievement.threshold).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        '$progress/${achievement.threshold}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
    );
  }

  List<Color> _getTierColors(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return [
          const Color(0xFFCD7F32),
          const Color(0xFFE5A04F),
        ];
      case AchievementTier.silver:
        return [
          const Color(0xFFC0C0C0),
          const Color(0xFFE0E0E0),
        ];
      case AchievementTier.gold:
        return [
          const Color(0xFFFFD700),
          const Color(0xFFFFF0A0),
        ];
      case AchievementTier.platinum:
        return [
          const Color(0xFF00CED1),
          const Color(0xFF7FFFD4),
        ];
    }
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
    final tier = AchievementTier.fromString(achievement.tier);
    final tierColors = _getTierColors(tier);

    return Card(
      elevation: isEarned ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        side: isEarned
            ? BorderSide(color: tierColors[0], width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space12),
          child: Row(
            children: [
              // Badge
              AchievementBadge(
                achievement: achievement,
                isEarned: isEarned,
                progress: progress,
                size: 60,
              ),
              const SizedBox(width: AppSizes.space12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            achievement.name,
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isEarned
                                          ? null
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                    ),
                          ),
                        ),
                        _buildTierChip(context, tier),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (isEarned && earnedAt != null)
                      Text(
                        'Earned ${_formatDate(earnedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tierColors[0],
                              fontWeight: FontWeight.w500,
                            ),
                      )
                    else if (progress != null)
                      _buildProgressBar(context, tier),
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
    final tierColors = _getTierColors(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tierColors[0].withOpacity(isEarned ? 1.0 : 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tier.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isEarned ? Colors.white : tierColors[0],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${achievement.points}pts',
            style: TextStyle(
              fontSize: 10,
              color: isEarned
                  ? Colors.white.withOpacity(0.8)
                  : tierColors[0].withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, AchievementTier tier) {
    final progressPercent = (progress! / achievement.threshold).clamp(0.0, 1.0);
    final tierColors = _getTierColors(tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
            Text(
              '$progress / ${achievement.threshold}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPercent,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(tierColors[0]),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  List<Color> _getTierColors(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFFE5A04F)];
      case AchievementTier.silver:
        return [const Color(0xFFC0C0C0), const Color(0xFFE0E0E0)];
      case AchievementTier.gold:
        return [const Color(0xFFFFD700), const Color(0xFFFFF0A0)];
      case AchievementTier.platinum:
        return [const Color(0xFF00CED1), const Color(0xFF7FFFD4)];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

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
