import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../data/models/achievement_model.dart';
import '../providers/achievements_provider.dart';
import '../widgets/achievement_detail_sheet.dart';

/// Achievements — screen 3k.
///
/// The points hero in lime, tab chips, a two-column badge grid, and the
/// leaderboard with the current user's row filled in the action colour.
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  static const List<String> _tabs = ['Earned', 'In progress', 'All'];
  String _tab = _tabs.first;

  /// Tiers the design does not name, so the caption is derived from points
  /// rather than invented. Each entry is the floor for that tier.
  static const List<(int, String)> _tiers = [
    (0, 'Wanderer I'),
    (250, 'Wanderer II'),
    (500, 'Explorer III'),
    (1000, 'Explorer IV'),
    (2000, 'Voyager V'),
    (4000, 'Voyager VI'),
    (8000, 'Odysseus'),
  ];

  (String, int?, double) _tierProgress(int points) {
    for (var i = _tiers.length - 1; i >= 0; i--) {
      if (points >= _tiers[i].$1) {
        final current = _tiers[i];
        final next = i + 1 < _tiers.length ? _tiers[i + 1] : null;
        if (next == null) return (current.$2, null, 1);

        final span = next.$1 - current.$1;
        final into = points - current.$1;
        return (current.$2, next.$1 - points, span == 0 ? 1 : into / span);
      }
    }
    return (_tiers.first.$2, _tiers[1].$1 - points, 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(achievementsProvider);
    final leaderboard = ref.watch(leaderboardProvider);
    final isPremium = ref.watch(isPremiumProvider);

    final (tierName, toNext, tierFraction) = _tierProgress(state.totalPoints);

    return Scaffold(
      backgroundColor: t.canvas,
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: () async {
          await ref.read(achievementsProvider.notifier).refresh();
          await ref.read(leaderboardProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            AppSizes.scrollBottom,
          ),
          children: [
            ScreenHeader(
              title: 'Achievements',
              onBack: () => context.pop(),
            ),
            const SizedBox(height: AppSizes.space20),

            if (state.isLoading && state.earned.isEmpty)
              const Column(
                children: [
                  Skeleton(
                    width: double.infinity,
                    height: 190,
                    radius: AppSizes.radiusHero,
                  ),
                  SizedBox(height: AppSizes.space12),
                  Skeleton.row(),
                ],
              )
            else if (state.error != null && state.earned.isEmpty)
              OdysseyErrorState(
                message: state.error!,
                onRetry: () => ref.read(achievementsProvider.notifier).refresh(),
              )
            else ...[
              _PointsHero(
                points: state.totalPoints,
                tierName: tierName,
                pointsToNext: toNext,
                fraction: tierFraction,
                earnedCount: state.totalEarned,
              ),
              const SizedBox(height: AppSizes.space18),

              ChipRow(
                labels: _tabs,
                selected: _tab,
                activeStyle: ChipActiveStyle.action,
                onSelected: (value) => setState(() => _tab = value),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSizes.space16),

              if (!isPremium) ...[
                _PremiumNudge(onTap: () => context.push(AppRoutes.subscription)),
                const SizedBox(height: AppSizes.space12),
              ],

              _BadgeGrid(
                tiles: _tilesForTab(state),
                onTap: _openDetail,
              ),

              if (leaderboard.entries.isNotEmpty) ...[
                const SizedBox(height: AppSizes.space26),
                const EyebrowLabel('Leaderboard · friends'),
                const SizedBox(height: AppSizes.space12),
                for (var i = 0; i < leaderboard.entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSizes.space10),
                  _LeaderboardRow(entry: leaderboard.entries[i]),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Every tab renders the same tile, so the three views differ only in what
  /// they put in the list.
  List<_BadgeTile> _tilesForTab(AchievementsState state) {
    List<_BadgeTile> earned() => state.earned
        .map(
          (u) => _BadgeTile(
            achievement: u.achievement,
            earned: true,
            progress: 1,
            userAchievement: u,
          ),
        )
        .toList();

    List<_BadgeTile> inProgress() => state.inProgress
        .map(
          (u) => _BadgeTile(
            achievement: u.achievement,
            earned: false,
            progress: u.achievement.threshold == 0
                ? 0
                : (u.progress / u.achievement.threshold).clamp(0.0, 1.0),
            userAchievement: u,
          ),
        )
        .toList();

    List<_BadgeTile> locked() => state.locked
        .map((a) => _BadgeTile(achievement: a, earned: false, progress: 0))
        .toList();

    return switch (_tab) {
      'Earned' => earned(),
      'In progress' => inProgress(),
      _ => [...earned(), ...inProgress(), ...locked()],
    };
  }

  void _openDetail(_BadgeTile tile) {
    HapticFeedback.lightImpact();
    showAchievementDetail(
      context: context,
      achievement: tile.achievement,
      userAchievement: tile.userAchievement,
    );
  }
}

/// The lime points hero. Lime in both themes, like every hero stat tile.
class _PointsHero extends StatelessWidget {
  const _PointsHero({
    required this.points,
    required this.tierName,
    required this.pointsToNext,
    required this.fraction,
    required this.earnedCount,
  });

  final int points;
  final String tierName;
  final int? pointsToNext;
  final double fraction;
  final int earnedCount;

  @override
  Widget build(BuildContext context) {
    return HeroTile(
      decorCorner: Alignment.bottomRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const EyebrowLabel(
            'Odyssey points',
            color: AppColors.onAccentLabel,
          ),
          const SizedBox(height: AppSizes.space12),
          Text(
            TripFormat.number(points),
            style: AppTypography.statHuge.copyWith(color: AppColors.onAccent),
            maxLines: 1,
          ),
          const SizedBox(height: AppSizes.space18),
          Row(
            children: [
              Expanded(
                child: ProgressTrack(
                  value: fraction,
                  trackColor: AppColors.onAccentTrack,
                  fillColor: AppColors.onAccent,
                ),
              ),
              const SizedBox(width: AppSizes.space12),
              Text(
                tierName,
                style: AppTypography.legend.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.onAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space10),
          Text(
            pointsToNext == null
                ? '$earnedCount badges · top tier reached'
                : '$pointsToNext points to the next tier',
            style: AppTypography.pill.copyWith(color: AppColors.onAccent2),
          ),
        ],
      ),
    );
  }
}

/// What a grid tile needs to render, flattened from the three shapes the
/// provider returns.
class _BadgeTile {
  const _BadgeTile({
    required this.achievement,
    required this.earned,
    required this.progress,
    this.userAchievement,
  });

  final Achievement achievement;
  final bool earned;
  final double progress;
  final UserAchievement? userAchievement;
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.tiles, required this.onTap});

  final List<_BadgeTile> tiles;
  final void Function(_BadgeTile) onTap;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const OdysseyEmptyState(
        icon: Icons.emoji_events_outlined,
        message: 'Nothing here yet. Badges arrive as you travel.',
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSizes.space12,
        mainAxisSpacing: AppSizes.space12,
        mainAxisExtent: 168,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) => _BadgeCard(
        tile: tiles[index],
        // Marks alternate circle and rounded square down the grid.
        circleMark: index.isOdd,
        onTap: () => onTap(tiles[index]),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.tile,
    required this.circleMark,
    required this.onTap,
  });

  final _BadgeTile tile;
  final bool circleMark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final earned = tile.earned;

    final markColor = earned
        ? t.action
        : (t.isDark ? const Color(0x1FFFFFFF) : const Color(0x1A0A0B0D));

    return Opacity(
      opacity: earned ? 1 : 0.72,
      child: OdysseyCard(
        radius: AppSizes.radiusTile,
        padding: const EdgeInsets.all(AppSizes.space18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: markColor,
                shape: circleMark ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circleMark
                    ? null
                    : BorderRadius.circular(AppSizes.radiusChip),
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            Text(
              tile.achievement.name,
              style: AppTypography.rowTitle.copyWith(color: t.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                tile.achievement.description,
                style: AppTypography.badgeDesc.copyWith(color: t.ink3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (earned)
              EyebrowLabel('Unlocked', tight: true, color: t.limeText)
            else if (tile.progress > 0)
              EyebrowLabel(
                '${(tile.progress * 100).round()}%',
                tight: true,
              )
            else
              const EyebrowLabel('Locked', tight: true),
          ],
        ),
      ),
    );
  }
}

/// A leaderboard row. The current user's row fills with the action colour.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final isYou = entry.isCurrentUser;

    final foreground = isYou ? t.onAction : t.ink;
    final secondary = isYou ? t.onAction.withValues(alpha: 0.7) : t.ink3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isYou ? t.action : t.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusRow),
        border: Border.all(color: isYou ? Colors.transparent : t.hairline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${entry.rank}',
              style: AppTypography.numeral.copyWith(color: secondary),
            ),
          ),
          const SizedBox(width: AppSizes.space10),
          AvatarCircle(name: entry.name, size: 34),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  style: AppTypography.rowLabel.copyWith(color: foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.achievementsEarned} badges',
                  style: AppTypography.rowMeta.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space10),
          Text(
            TripFormat.number(entry.totalPoints),
            style: AppTypography.numeral.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// A quiet line rather than a banner. The old screen gave this a full card;
/// in this system an upsell that loud would outrank the badges it sits above.
class _PremiumNudge extends StatelessWidget {
  const _PremiumNudge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return OdysseyCard(
      radius: AppSizes.radiusRow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pro unlocks every badge category.',
              style: AppTypography.rowMeta.copyWith(color: t.ink2),
            ),
          ),
          const SizedBox(width: AppSizes.space10),
          Text(
            'See Pro',
            style: AppTypography.caption.copyWith(color: t.limeText),
          ),
        ],
      ),
    );
  }
}
