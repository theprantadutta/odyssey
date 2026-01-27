import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/trip_share_model.dart';
import '../providers/sharing_provider.dart';

class SharedTripsScreen extends ConsumerWidget {
  const SharedTripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedTripsState = ref.watch(sharedTripsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _buildBackButton(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared with Me',
              style: AppTypography.headlineSmall.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Trips from friends and family',
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSizes.space16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.oceanTeal),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(sharedTripsProvider.notifier).refresh();
              },
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.sunnyYellow,
        backgroundColor: colorScheme.surface,
        onRefresh: () => ref.read(sharedTripsProvider.notifier).refresh(),
        child: _buildContent(context, sharedTripsState, ref),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSizes.space8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SharedTripsState state,
    WidgetRef ref,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.sunnyYellow),
      );
    }

    if (state.error != null) {
      return _ErrorState(
        error: state.error!,
        onRetry: () => ref.read(sharedTripsProvider.notifier).refresh(),
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
    final dateFormat = DateFormat('MMM d, yyyy');
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/trips/${trip.tripId}');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              if (trip.coverImageUrl != null)
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: trip.coverImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 140,
                        placeholder: (context, url) => Container(
                          color: AppColors.lemonLight,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.sunnyYellow,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildPlaceholderCover(),
                      ),
                      // Gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Status badge
                      Positioned(
                        top: AppSizes.space12,
                        right: AppSizes.space12,
                        child: _TripStatusBadge(status: trip.status),
                      ),
                    ],
                  ),
                )
              else
                Stack(
                  children: [
                    _buildPlaceholderCover(),
                    Positioned(
                      top: AppSizes.space12,
                      right: AppSizes.space12,
                      child: _TripStatusBadge(status: trip.status),
                    ),
                  ],
                ),

              Padding(
                padding: const EdgeInsets.all(AppSizes.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Shared by indicator
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.oceanTeal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.oceanTeal,
                          ),
                        ),
                        const SizedBox(width: AppSizes.space8),
                        Expanded(
                          child: Text(
                            'Shared by ${trip.ownerEmail}',
                            style: AppTypography.bodySmall.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _PermissionBadge(permission: trip.permission),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space12),

                    // Title
                    Text(
                      trip.title,
                      style: AppTypography.titleMedium.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (trip.description != null) ...[
                      const SizedBox(height: AppSizes.space4),
                      Text(
                        trip.description!,
                        style: AppTypography.bodySmall.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: AppSizes.space12),

                    // Date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.lemonLight,
                            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                          ),
                          child: const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.goldenGlow,
                          ),
                        ),
                        const SizedBox(width: AppSizes.space8),
                        Expanded(
                          child: Text(
                            trip.endDate != null
                                ? '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate!)}'
                                : dateFormat.format(trip.startDate),
                            style: AppTypography.bodySmall.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.space12,
                            vertical: AppSizes.space4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.sunnyYellow,
                            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppColors.charcoal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'View',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.charcoal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lemonLight,
            AppColors.sunnyYellow.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.flight_takeoff,
          size: 48,
          color: AppColors.sunnyYellow.withValues(alpha: 0.5),
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
    final isEdit = permission == SharePermission.edit;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: isEdit
            ? AppColors.lavenderDream.withValues(alpha: 0.1)
            : AppColors.oceanTeal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(
          color: isEdit
              ? AppColors.lavenderDream.withValues(alpha: 0.3)
              : AppColors.oceanTeal.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEdit ? Icons.edit_outlined : Icons.visibility_outlined,
            size: 12,
            color: isEdit ? AppColors.lavenderDream : AppColors.oceanTeal,
          ),
          const SizedBox(width: 4),
          Text(
            permission.displayName,
            style: AppTypography.labelSmall.copyWith(
              color: isEdit ? AppColors.lavenderDream : AppColors.oceanTeal,
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
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status.toLowerCase()) {
      case 'ongoing':
        bgColor = AppColors.oceanTeal;
        textColor = Colors.white;
        icon = Icons.flight_takeoff;
        label = 'Ongoing';
        break;
      case 'completed':
        bgColor = AppColors.success;
        textColor = Colors.white;
        icon = Icons.check_circle_outline;
        label = 'Completed';
        break;
      default:
        bgColor = AppColors.sunnyYellow;
        textColor = AppColors.charcoal;
        icon = Icons.schedule;
        label = 'Planned';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: textColor,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space24),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sunnyYellow.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.sunnyYellow,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'No shared trips yet',
              style: AppTypography.headlineSmall.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'When someone shares a trip with you,\nit will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.space16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space20,
                vertical: AppSizes.space12,
              ),
              decoration: BoxDecoration(
                color: AppColors.oceanTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: AppColors.oceanTeal,
                  ),
                  const SizedBox(width: AppSizes.space8),
                  Text(
                    'Ask friends to share their travel plans!',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.oceanTeal,
                      fontWeight: FontWeight.w500,
                    ),
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

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 56,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space20),
            Text(
              'Failed to load shared trips',
              style: AppTypography.headlineSmall.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.sunnyYellow,
                foregroundColor: AppColors.charcoal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space24,
                  vertical: AppSizes.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(
                'Retry',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
