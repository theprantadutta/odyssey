import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../data/models/achievement_model.dart';
import '../providers/achievements_provider.dart';
import '../widgets/achievement_badge.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final achievementsState = ref.watch(achievementsProvider);
    final totalPoints = achievementsState.totalPoints;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Earned'),
            Tab(text: 'In Progress'),
            Tab(text: 'Locked'),
          ],
        ),
        actions: [
          // Points display
          Container(
            margin: const EdgeInsets.only(right: AppSizes.space16),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space12,
              vertical: AppSizes.space4,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.stars,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$totalPoints pts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: achievementsState.isLoading && achievementsState.earned.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : achievementsState.error != null && achievementsState.earned.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: AppSizes.space16),
                      const Text('Failed to load achievements'),
                      const SizedBox(height: AppSizes.space8),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(achievementsProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _EarnedTab(achievements: achievementsState.earned),
                    _InProgressTab(achievements: achievementsState.inProgress),
                    _LockedTab(achievements: achievementsState.locked),
                  ],
                ),
    );
  }
}

class _EarnedTab extends StatelessWidget {
  final List<UserAchievement> achievements;

  const _EarnedTab({required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const _EmptyState(
        icon: Icons.emoji_events_outlined,
        title: 'No achievements yet',
        subtitle: 'Start traveling to unlock achievements!',
      );
    }

    // Group by category
    final byCategory = <AchievementCategory, List<UserAchievement>>{};
    for (final ua in achievements) {
      final category = AchievementCategory.fromString(ua.achievement.category);
      byCategory.putIfAbsent(category, () => []).add(ua);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.space16),
      itemCount: byCategory.length,
      itemBuilder: (context, index) {
        final category = byCategory.keys.elementAt(index);
        final categoryAchievements = byCategory[category]!;

        return _CategorySection(
          category: category,
          children: categoryAchievements
              .map((ua) => AchievementCard(
                    achievement: ua.achievement,
                    isEarned: true,
                    earnedAt: ua.earnedAt,
                    onTap: () => _showAchievementDetails(context, ua),
                  ))
              .toList(),
        );
      },
    );
  }

  void _showAchievementDetails(BuildContext context, UserAchievement ua) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AchievementDetailSheet(
        achievement: ua.achievement,
        earnedAt: ua.earnedAt,
        isEarned: true,
      ),
    );
  }
}

class _InProgressTab extends StatelessWidget {
  final List<UserAchievement> achievements;

  const _InProgressTab({required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const _EmptyState(
        icon: Icons.trending_up,
        title: 'No achievements in progress',
        subtitle: 'Keep exploring to make progress!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.space16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final ua = achievements[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.space12),
          child: AchievementCard(
            achievement: ua.achievement,
            isEarned: false,
            progress: ua.progress,
            onTap: () => _showAchievementDetails(context, ua),
          ),
        );
      },
    );
  }

  void _showAchievementDetails(BuildContext context, UserAchievement ua) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AchievementDetailSheet(
        achievement: ua.achievement,
        progress: ua.progress,
        isEarned: false,
      ),
    );
  }
}

class _LockedTab extends StatelessWidget {
  final List<Achievement> achievements;

  const _LockedTab({required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return const _EmptyState(
        icon: Icons.star,
        title: 'All achievements unlocked!',
        subtitle: 'Congratulations, you\'ve earned them all!',
      );
    }

    // Group by tier
    final byTier = <AchievementTier, List<Achievement>>{};
    for (final a in achievements) {
      final tier = AchievementTier.fromString(a.tier);
      byTier.putIfAbsent(tier, () => []).add(a);
    }

    // Sort tiers
    final sortedTiers = [
      AchievementTier.bronze,
      AchievementTier.silver,
      AchievementTier.gold,
      AchievementTier.platinum,
    ].where((t) => byTier.containsKey(t)).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.space16),
      itemCount: sortedTiers.length,
      itemBuilder: (context, index) {
        final tier = sortedTiers[index];
        final tierAchievements = byTier[tier]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TierHeader(tier: tier, count: tierAchievements.length),
            const SizedBox(height: AppSizes.space12),
            Wrap(
              spacing: AppSizes.space12,
              runSpacing: AppSizes.space16,
              children: tierAchievements
                  .map((a) => AchievementBadge(
                        achievement: a,
                        isEarned: false,
                        size: 70,
                        onTap: () => _showAchievementDetails(context, a),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSizes.space24),
          ],
        );
      },
    );
  }

  void _showAchievementDetails(BuildContext context, Achievement a) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AchievementDetailSheet(
        achievement: a,
        isEarned: false,
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final AchievementCategory category;
  final List<Widget> children;

  const _CategorySection({
    required this.category,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              category.displayName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${children.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space12),
        ...children.map((child) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.space12),
              child: child,
            )),
        const SizedBox(height: AppSizes.space8),
      ],
    );
  }

  IconData _getCategoryIcon(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.trips:
        return Icons.flight_takeoff;
      case AchievementCategory.activities:
        return Icons.local_activity;
      case AchievementCategory.memories:
        return Icons.photo_camera;
      case AchievementCategory.packing:
        return Icons.luggage;
      case AchievementCategory.social:
        return Icons.people;
      case AchievementCategory.budget:
        return Icons.account_balance_wallet;
      case AchievementCategory.special:
        return Icons.auto_awesome;
    }
  }
}

class _TierHeader extends StatelessWidget {
  final AchievementTier tier;
  final int count;

  const _TierHeader({required this.tier, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = _getTierColors(tier);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors[0].withOpacity(0.2), colors[1].withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: colors[0].withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            '${tier.displayName} Tier',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors[0],
            ),
          ),
          const Spacer(),
          Text(
            '$count locked',
            style: TextStyle(
              fontSize: 12,
              color: colors[0].withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getTierColors(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFFE5A04F)];
      case AchievementTier.silver:
        return [const Color(0xFF9E9E9E), const Color(0xFFC0C0C0)];
      case AchievementTier.gold:
        return [const Color(0xFFFFAB00), const Color(0xFFFFD700)];
      case AchievementTier.platinum:
        return [const Color(0xFF00ACC1), const Color(0xFF00CED1)];
    }
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: AppSizes.space16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementDetailSheet extends StatelessWidget {
  final Achievement achievement;
  final int? progress;
  final DateTime? earnedAt;
  final bool isEarned;

  const _AchievementDetailSheet({
    required this.achievement,
    this.progress,
    this.earnedAt,
    required this.isEarned,
  });

  @override
  Widget build(BuildContext context) {
    final tier = AchievementTier.fromString(achievement.tier);
    final colors = _getTierColors(tier);

    return Container(
      padding: const EdgeInsets.all(AppSizes.space24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSizes.space24),
          // Badge
          AchievementBadge(
            achievement: achievement,
            isEarned: isEarned,
            progress: progress,
            size: 100,
          ),
          const SizedBox(height: AppSizes.space16),
          // Name
          Text(
            achievement.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.space8),
          // Description
          Text(
            achievement.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.space16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip(
                icon: Icons.stars,
                label: '${achievement.points} pts',
                color: colors[0],
              ),
              const SizedBox(width: AppSizes.space12),
              _StatChip(
                icon: Icons.workspace_premium,
                label: tier.displayName,
                color: colors[0],
              ),
              const SizedBox(width: AppSizes.space12),
              _StatChip(
                icon: Icons.category,
                label: AchievementCategory.fromString(achievement.category)
                    .displayName,
                color: colors[0],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          // Status
          if (isEarned && earnedAt != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space8,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Earned on ${_formatDate(earnedAt!)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else if (progress != null)
            Column(
              children: [
                Text(
                  'Progress: $progress / ${achievement.threshold}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSizes.space8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:
                        (progress! / achievement.threshold).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(colors[0]),
                    minHeight: 8,
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space8,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      color: Colors.grey.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Complete ${achievement.threshold} to unlock',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSizes.space24),
        ],
      ),
    );
  }

  List<Color> _getTierColors(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return [const Color(0xFFCD7F32), const Color(0xFFE5A04F)];
      case AchievementTier.silver:
        return [const Color(0xFF9E9E9E), const Color(0xFFC0C0C0)];
      case AchievementTier.gold:
        return [const Color(0xFFFFAB00), const Color(0xFFFFD700)];
      case AchievementTier.platinum:
        return [const Color(0xFF00ACC1), const Color(0xFF00CED1)];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
