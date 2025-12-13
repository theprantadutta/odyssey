import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/sharing/data/models/trip_share_model.dart';
import 'package:odyssey/src/features/sharing/presentation/providers/sharing_provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SharedTripsScreen extends ConsumerWidget {
  const SharedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedTripsState = ref.watch(sharedTripsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared with Me'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(sharedTripsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(sharedTripsProvider.notifier).refresh(),
        child: _buildContent(context, sharedTripsState, theme),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SharedTripsState state,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _ErrorState(
        error: state.error!,
        onRetry: () {},
      );
    }

    if (state.trips.isEmpty) {
      return const _NoSharedTripsState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.space16),
      itemCount: state.trips.length,
      itemBuilder: (context, index) {
        final trip = state.trips[index];
        return _SharedTripCard(trip: trip);
      },
    );
  }
}

class _SharedTripCard extends StatelessWidget {
  final SharedTripInfo trip;

  const _SharedTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.space16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: InkWell(
        onTap: () => context.push('/trips/${trip.tripId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (trip.coverImageUrl != null)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: trip.coverImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.oceanTeal.withValues(alpha: 0.1),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.oceanTeal.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 48,
                      color: AppColors.oceanTeal,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.oceanTeal.withValues(alpha: 0.3),
                      AppColors.lavenderDream.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  size: 48,
                  color: AppColors.oceanTeal,
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shared by indicator
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSizes.space4),
                      Text(
                        'Shared by ${trip.ownerEmail}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      _PermissionBadge(permission: trip.permission),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space8),

                  // Title
                  Text(
                    trip.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (trip.description != null) ...[
                    const SizedBox(height: AppSizes.space4),
                    Text(
                      trip.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: AppSizes.space12),

                  // Date and status
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSizes.space4),
                      Text(
                        trip.endDate != null
                            ? '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate!)}'
                            : dateFormat.format(trip.startDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      _TripStatusBadge(status: trip.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionBadge extends StatelessWidget {
  final SharePermission permission;

  const _PermissionBadge({required this.permission});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.oceanTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            permission == SharePermission.view
                ? Icons.visibility_outlined
                : Icons.edit_outlined,
            size: 12,
            color: AppColors.oceanTeal,
          ),
          const SizedBox(width: 4),
          Text(
            permission.displayName,
            style: const TextStyle(
              color: AppColors.oceanTeal,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripStatusBadge extends StatelessWidget {
  final String status;

  const _TripStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'ongoing':
        color = AppColors.oceanTeal;
        icon = Icons.flight_takeoff;
        label = 'Ongoing';
        break;
      case 'completed':
        color = AppColors.success;
        icon = Icons.check_circle_outline;
        label = 'Completed';
        break;
      default:
        color = AppColors.warning;
        icon = Icons.schedule;
        label = 'Planned';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSharedTripsState extends StatelessWidget {
  const _NoSharedTripsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space24),
              decoration: BoxDecoration(
                color: AppColors.oceanTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.oceanTeal,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'No shared trips yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'When someone shares a trip with you, it will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Ask your friends to share their travel plans!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.space16),
            Text(
              'Failed to load shared trips',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.space16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
