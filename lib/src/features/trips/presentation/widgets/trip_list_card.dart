import 'package:flutter/material.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/trip_model.dart';

/// A trip in the Trips list: a wide cover with the title set over the scrim,
/// the date range beneath it, and a lime day badge while the trip is running.
///
/// This is the full-width sibling of the 150px thumb on Home. Text over the
/// photo stays the light-on-dark set in both themes — the scrim guarantees it.
class TripListCard extends StatelessWidget {
  const TripListCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onLongPress,
  });

  final TripModel trip;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final start = TripFormat.parse(trip.startDate);
    final end = TripFormat.parse(trip.endDate);
    final progress = TripFormat.dayProgress(start, end);
    final countdown = TripFormat.countdown(start, end);

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppSizes.radiusHero),
      tint: false,
      semanticLabel: trip.title,
      child: PhotoSurface(
        imageUrl: trip.coverImageUrl,
        seed: trip.id,
        height: 210,
        radius: AppSizes.radiusHero,
        child: Stack(
          children: [
            if (countdown != null)
              Positioned(
                right: AppSizes.space14,
                top: AppSizes.space14,
                child: PhotoPill(label: countdown),
              ),
            if (progress != null)
              Positioned(
                left: AppSizes.space14,
                top: AppSizes.space14,
                child: OdysseyBadge('DAY ${progress.$1} / ${progress.$2}'),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.space18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trip.title,
                      style: AppTypography.statCard.copyWith(
                        color: AppColors.onPhoto,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.space6),
                    Text(
                      TripFormat.dateRange(start, end),
                      style: AppTypography.metaLarge.copyWith(
                        color: AppColors.onPhoto2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The skeleton shown while the first page of trips loads.
class TripListSkeleton extends StatelessWidget {
  const TripListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.space12),
          const Skeleton(
            width: double.infinity,
            height: 210,
            radius: AppSizes.radiusHero,
          ),
        ],
      ],
    );
  }
}

/// The row of status chips above the list. Single-select, and a view filter
/// over what the provider already holds rather than a re-query.
class TripStatusChips extends StatelessWidget {
  const TripStatusChips({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.counts,
  });

  static const List<String> labels = ['All', 'Planned', 'Ongoing', 'Completed'];

  final String selected;
  final ValueChanged<String> onSelected;

  /// Trip counts per label, used to grey out a filter that would show nothing.
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSizes.space8),
            Opacity(
              opacity: (counts[labels[i]] ?? 0) == 0 && labels[i] != selected
                  ? 0.45
                  : 1,
              child: OdysseyChip(
                label: labels[i],
                selected: labels[i] == selected,
                onTap: () => onSelected(labels[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
