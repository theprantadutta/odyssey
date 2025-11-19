import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/glass_container.dart';
import '../../data/models/trip_model.dart';

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: AppSizes.tripCardHeight,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space8,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image with Hero Animation
            Hero(
              tag: 'trip-${trip.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                child: _buildImage(),
              ),
            ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.midnightBlue.withOpacity(0.3),
                    AppColors.midnightBlue.withOpacity(0.9),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Content Overlay
            Positioned(
              left: AppSizes.space16,
              right: AppSizes.space16,
              bottom: AppSizes.space16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status Badge
                  _buildStatusBadge(),
                  const SizedBox(height: AppSizes.space8),

                  // Title
                  Text(
                    trip.title,
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.textOnDark,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.space8),

                  // Date Range
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: AppSizes.iconXs,
                        color: AppColors.softGold,
                      ),
                      const SizedBox(width: AppSizes.space8),
                      Text(
                        _formatDateRange(),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.softGold,
                        ),
                      ),
                    ],
                  ),

                  // Tags
                  if (trip.tags != null && trip.tags!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.space8),
                      child: Wrap(
                        spacing: AppSizes.space8,
                        runSpacing: AppSizes.space4,
                        children: trip.tags!.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.space8,
                              vertical: AppSizes.space4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.sunsetGold.withOpacity(0.2),
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusFull),
                              border: Border.all(
                                color: AppColors.sunsetGold.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.softGold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            // Action Buttons
            if (onEdit != null || onDelete != null)
              Positioned(
                top: AppSizes.space12,
                right: AppSizes.space12,
                child: Row(
                  children: [
                    if (onEdit != null)
                      GlassContainer(
                        opacity: 0.3,
                        borderRadius: AppSizes.radiusSm,
                        padding: const EdgeInsets.all(AppSizes.space8),
                        child: InkWell(
                          onTap: onEdit,
                          child: Icon(
                            Icons.edit_outlined,
                            size: AppSizes.iconSm,
                            color: AppColors.textOnDark,
                          ),
                        ),
                      ),
                    if (onEdit != null && onDelete != null)
                      const SizedBox(width: AppSizes.space8),
                    if (onDelete != null)
                      GlassContainer(
                        opacity: 0.3,
                        borderRadius: AppSizes.radiusSm,
                        padding: const EdgeInsets.all(AppSizes.space8),
                        child: InkWell(
                          onTap: onDelete,
                          child: Icon(
                            Icons.delete_outline,
                            size: AppSizes.iconSm,
                            color: AppColors.error,
                          ),
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

  Widget _buildImage() {
    if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: trip.coverImageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.deepNavy,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.sunsetGold),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.deepNavy,
          child: Icon(
            Icons.travel_explore,
            size: 64,
            color: AppColors.sunsetGold.withOpacity(0.3),
          ),
        ),
      );
    }

    // Default placeholder
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Center(
        child: Icon(
          Icons.travel_explore,
          size: 64,
          color: AppColors.sunsetGold.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = TripStatus.values.firstWhere(
      (s) => s.name == trip.status,
      orElse: () => TripStatus.planned,
    );

    Color badgeColor;
    IconData icon;

    switch (status) {
      case TripStatus.planned:
        badgeColor = AppColors.info;
        icon = Icons.schedule;
        break;
      case TripStatus.ongoing:
        badgeColor = AppColors.success;
        icon = Icons.flight_takeoff;
        break;
      case TripStatus.completed:
        badgeColor = AppColors.textTertiary;
        icon = Icons.check_circle_outline;
        break;
    }

    return GoldGlassContainer(
      borderRadius: AppSizes.radiusFull,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppSizes.iconXs,
            color: badgeColor,
          ),
          const SizedBox(width: AppSizes.space4),
          Text(
            status.displayName,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange() {
    try {
      final startDate = DateTime.parse(trip.startDate);
      final endDate = DateTime.parse(trip.endDate);
      final formatter = DateFormat('MMM d, yyyy');

      if (startDate.year == endDate.year &&
          startDate.month == endDate.month) {
        return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('d, yyyy').format(endDate)}';
      }

      return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
    } catch (e) {
      return '${trip.startDate} - ${trip.endDate}';
    }
  }
}
