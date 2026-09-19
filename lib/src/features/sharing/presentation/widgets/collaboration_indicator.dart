import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../providers/sharing_provider.dart';

/// How many people are on this trip, shown on the trip cover.
///
/// It sits on a photograph, so it wears the glass pill treatment the other
/// controls up there use rather than a themed card.
class CollaborationIndicator extends ConsumerWidget {
  const CollaborationIndicator({
    super.key,
    required this.tripId,
    this.onTap,
  });

  final String tripId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref
        .watch(tripSharesProvider(tripId))
        .acceptedShares
        .length;

    if (count == 0) return const SizedBox.shrink();

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      tint: false,
      semanticLabel: '$count travelling with you',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.photoChipBg,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(color: AppColors.photoTagBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline,
              size: 14,
              color: AppColors.onPhoto,
            ),
            const SizedBox(width: AppSizes.space6),
            Text(
              '$count',
              style: AppTypography.countdown.copyWith(
                color: AppColors.onPhoto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stack of collaborator avatars, overlapping.
class CollaboratorAvatars extends ConsumerWidget {
  const CollaboratorAvatars({
    super.key,
    required this.tripId,
    this.maxAvatars = 3,
    this.avatarSize = 28,
  });

  final String tripId;
  final int maxAvatars;
  final double avatarSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shares = ref.watch(tripSharesProvider(tripId)).acceptedShares;
    if (shares.isEmpty) return const SizedBox.shrink();

    final shown = shares.take(maxAvatars).toList();
    final extra = shares.length - shown.length;

    return SizedBox(
      height: avatarSize,
      // Each avatar overlaps the one before it by a third of its width, so a
      // group reads as a group rather than a row.
      width: avatarSize + (shown.length - 1) * avatarSize * 0.66 +
          (extra > 0 ? avatarSize * 0.66 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * avatarSize * 0.66,
              child: AvatarCircle(
                name: shown[i].sharedWithEmail,
                size: avatarSize,
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * avatarSize * 0.66,
              child: _OverflowAvatar(count: extra, size: avatarSize),
            ),
        ],
      ),
    );
  }
}

class _OverflowAvatar extends StatelessWidget {
  const _OverflowAvatar({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.photoChipBg,
        shape: BoxShape.circle,
      ),
      child: Text(
        '+$count',
        style: AppTypography.avatarInitial.copyWith(
          fontSize: size * 0.32,
          color: AppColors.onPhoto,
        ),
      ),
    );
  }
}
