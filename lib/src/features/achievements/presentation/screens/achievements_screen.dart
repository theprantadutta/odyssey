import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
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
      backgroundColor: AppColors.cloudGray,
      appBar: AppBar(
        backgroundColor: AppColors.cloudGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: AppSizes.space16,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.snowWhite,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: AppSizes.softShadow,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.charcoal,
              size: 20,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Achievements',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Collect badges as you explore',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.slate,
              ),
            ),
          ],
        ),
        actions: [
          // Points badge
          Container(
            margin: const EdgeInsets.only(right: AppSizes.space16),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space12,
              vertical: AppSizes.space8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.sunnyYellow,
                  AppColors.sunnyYellow.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sunnyYellow.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '$totalPoints pts',
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
            decoration: BoxDecoration(
              color: AppColors.snowWhite,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              boxShadow: AppSizes.softShadow,
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.sunnyYellow,
              unselectedLabelColor: AppColors.slate,
              labelStyle: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTypography.labelMedium,
              indicator: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              splashBorderRadius: BorderRadius.circular(AppSizes.radiusMd),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'Earned'),
                Tab(text: 'In Progress'),
                Tab(text: 'Locked'),
              ],
            ),
          ),
        ),
      ),
      body: achievementsState.isLoading && achievementsState.earned.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.lemonLight,
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: AppColors.sunnyYellow,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),
                  Text(
                    'Loading achievements...',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            )
          : achievementsState.error != null && achievementsState.earned.isEmpty
              ? _buildErrorState(context, ref)
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

  Widget _buildErrorState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Failed to load achievements',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Please check your connection and try again',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(achievementsProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sunnyYellow,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space24,
                  vertical: AppSizes.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
            ),
          ],
        ),
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
        color: AppColors.sunnyYellow,
      );
    }

    // Group by category
    final byCategory = <AchievementCategory, List<UserAchievement>>{};
    for (final ua in achievements) {
      final category = AchievementCategory.fromString(ua.achievement.category);
      byCategory.putIfAbsent(category, () => []).add(ua);
    }

    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      backgroundColor: AppColors.snowWhite,
      onRefresh: () async {},
      child: ListView.builder(
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
      ),
    );
  }

  void _showAchievementDetails(BuildContext context, UserAchievement ua) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.snowWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        icon: Icons.trending_up_rounded,
        title: 'No achievements in progress',
        subtitle: 'Keep exploring to make progress!',
        color: AppColors.oceanTeal,
      );
    }

    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      backgroundColor: AppColors.snowWhite,
      onRefresh: () async {},
      child: ListView.builder(
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
      ),
    );
  }

  void _showAchievementDetails(BuildContext context, UserAchievement ua) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.snowWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        icon: Icons.star_rounded,
        title: 'All achievements unlocked!',
        subtitle: 'Congratulations, you\'ve earned them all!',
        color: AppColors.mintGreen,
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

    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      backgroundColor: AppColors.snowWhite,
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.space16),
        itemCount: sortedTiers.length,
        itemBuilder: (context, index) {
          final tier = sortedTiers[index];
          final tierAchievements = byTier[tier]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TierHeader(tier: tier, count: tierAchievements.length),
              const SizedBox(height: AppSizes.space16),
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
      ),
    );
  }

  void _showAchievementDetails(BuildContext context, Achievement a) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.snowWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
    final color = _getCategoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space16),
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Expanded(
                child: Text(
                  category.displayName,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space8,
                  vertical: AppSizes.space4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                ),
                child: Text(
                  '${children.length}',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          ...children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.space12),
                child: child,
              )),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.trips:
        return Icons.flight_takeoff_rounded;
      case AchievementCategory.activities:
        return Icons.local_activity_rounded;
      case AchievementCategory.memories:
        return Icons.photo_camera_rounded;
      case AchievementCategory.packing:
        return Icons.luggage_rounded;
      case AchievementCategory.social:
        return Icons.people_rounded;
      case AchievementCategory.budget:
        return Icons.account_balance_wallet_rounded;
      case AchievementCategory.special:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _getCategoryColor(AchievementCategory category) {
    switch (category) {
      case AchievementCategory.trips:
        return AppColors.oceanTeal;
      case AchievementCategory.activities:
        return AppColors.coralBurst;
      case AchievementCategory.memories:
        return AppColors.lavenderDream;
      case AchievementCategory.packing:
        return AppColors.mintGreen;
      case AchievementCategory.social:
        return AppColors.sunnyYellow;
      case AchievementCategory.budget:
        return AppColors.oceanTeal;
      case AchievementCategory.special:
        return AppColors.coralBurst;
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
        horizontal: AppSizes.space16,
        vertical: AppSizes.space12,
      ),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: AppSizes.softShadow,
        border: Border.all(
          color: colors[0].withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors[0].withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tier.displayName} Tier',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors[0],
                  ),
                ),
                Text(
                  '$count achievements locked',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space8,
              vertical: AppSizes.space4,
            ),
            decoration: BoxDecoration(
              color: colors[0].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: Text(
              '$count',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: colors[0],
              ),
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
  final Color color;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: color,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.charcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate,
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
              color: AppColors.mutedGray,
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
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.space8),
          // Description
          Text(
            achievement.description,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.slate,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.space20),
          // Stats row
          Wrap(
            spacing: AppSizes.space8,
            runSpacing: AppSizes.space8,
            alignment: WrapAlignment.center,
            children: [
              _StatChip(
                icon: Icons.stars_rounded,
                label: '${achievement.points} pts',
                color: colors[0],
              ),
              _StatChip(
                icon: Icons.workspace_premium_rounded,
                label: tier.displayName,
                color: colors[0],
              ),
              _StatChip(
                icon: Icons.category_rounded,
                label: AchievementCategory.fromString(achievement.category)
                    .displayName,
                color: colors[0],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space20),
          // Status
          if (isEarned && earnedAt != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space12,
              ),
              decoration: BoxDecoration(
                color: AppColors.mintGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: AppColors.mintGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.mintGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Earned on ${_formatDate(earnedAt!)}',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.mintGreen,
                      fontWeight: FontWeight.w600,
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
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.warmGray,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress! / achievement.threshold).clamp(0.0, 1.0),
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(colors[0]),
                      minHeight: 8,
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space12,
              ),
              decoration: BoxDecoration(
                color: AppColors.warmGray,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.slate, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Complete ${achievement.threshold} to unlock',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.slate,
                      fontWeight: FontWeight.w600,
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
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
