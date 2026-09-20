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
import '../../../ads/native_ad_slots.dart';
import '../../../ads/presentation/widgets/native_ad_list_tile.dart';
import '../../data/models/trip_share_model.dart';
import '../providers/sharing_provider.dart';

/// Trips other people have shared with you.
class SharedTripsScreen extends ConsumerWidget {
  const SharedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.odyssey;
    final state = ref.watch(sharedTripsProvider);
    final slots = NativeAdSlots(state.trips.length);

    return OdysseyScaffold(
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: () => ref.read(sharedTripsProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            AppSizes.scrollBottom,
          ),
          children: [
            ScreenHeader(onBack: () => context.pop()),
            const SizedBox(height: AppSizes.space20),
            Text(
              'Shared\nwith you',
              style: AppTypography.screenTitle.copyWith(color: t.ink),
            ),
            if (state.trips.isNotEmpty) ...[
              const SizedBox(height: AppSizes.space8),
              Text(
                '${state.trips.length} '
                '${state.trips.length == 1 ? 'trip' : 'trips'}',
                style: AppTypography.meta.copyWith(color: t.ink3),
              ),
            ],
            const SizedBox(height: AppSizes.space20),

            if (state.isLoading && state.trips.isEmpty)
              const Column(
                children: [
                  Skeleton(
                    width: double.infinity,
                    height: 190,
                    radius: AppSizes.radiusHero,
                  ),
                  SizedBox(height: AppSizes.space12),
                  Skeleton(
                    width: double.infinity,
                    height: 190,
                    radius: AppSizes.radiusHero,
                  ),
                ],
              )
            else if (state.error != null && state.trips.isEmpty)
              OdysseyErrorState(
                message: state.error!,
                onRetry: () => ref.read(sharedTripsProvider.notifier).refresh(),
              )
            else if (state.trips.isEmpty)
              const OdysseyEmptyState(
                icon: Icons.groups_outlined,
                message: 'Nothing shared with you yet. When someone invites '
                    'you to a trip, it lands here.',
              )
            else
              for (var i = 0; i < state.trips.length; i++) ...[
                if (slots.isAdAt(i)) ...[
                  const NativeAdListTile(),
                  const SizedBox(height: AppSizes.space12),
                ],
                _SharedTripCard(trip: state.trips[i]),
                const SizedBox(height: AppSizes.space12),
              ],
          ],
        ),
      ),
    );
  }
}

class _SharedTripCard extends StatelessWidget {
  const _SharedTripCard({required this.trip});

  final SharedTripInfo trip;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PhotoSurface(
          imageUrl: trip.coverImageUrl,
          seed: trip.tripId,
          height: 190,
          radius: AppSizes.radiusHero,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('${AppRoutes.tripDetail}/${trip.tripId}');
          },
          child: Stack(
            children: [
              Positioned(
                right: AppSizes.space14,
                top: AppSizes.space14,
                child: PhotoPill(
                  label: trip.permission.displayName,
                  showDot: false,
                ),
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
                        TripFormat.dateRange(trip.startDate, trip.endDate),
                        style: AppTypography.metaLarge.copyWith(
                          color: AppColors.onPhoto2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.space10),
        Row(
          children: [
            AvatarCircle(name: trip.ownerEmail, size: 28),
            const SizedBox(width: AppSizes.space10),
            Expanded(
              child: Text(
                'Shared by ${trip.ownerEmail}',
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              TripFormat.shortDate(trip.sharedAt),
              style: AppTypography.rowMeta.copyWith(color: t.ink3),
            ),
          ],
        ),
      ],
    );
  }
}
