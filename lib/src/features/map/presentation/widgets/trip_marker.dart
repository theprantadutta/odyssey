import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../providers/map_provider.dart';

class TripMarker extends StatelessWidget {
  final TripLocation trip;
  final VoidCallback? onTap;
  final bool isSelected;

  const TripMarker({
    super.key,
    required this.trip,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _getStatusColor(trip.status, colorScheme);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSelected ? 50 : 40,
        height: isSelected ? 50 : 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: isSelected ? 12 : 8,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: ClipOval(
          child: trip.coverImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: trip.coverImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(color),
                  errorWidget: (context, url, error) =>
                      _buildPlaceholder(color),
                )
              : _buildPlaceholder(color),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(Color color) {
    return Container(
      color: color,
      child: Icon(
        _getStatusIcon(trip.status),
        color: Colors.white,
        size: isSelected ? 24 : 20,
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'planned':
        return Icons.schedule;
      case 'ongoing':
        return Icons.flight_takeoff;
      case 'completed':
        return Icons.check;
      default:
        return Icons.place;
    }
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'planned':
        return AppColors.sunnyYellow;
      case 'ongoing':
        return AppColors.oceanTeal;
      case 'completed':
        return AppColors.mintGreen;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }
}

class TripInfoCard extends StatelessWidget {
  final TripLocation trip;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  const TripInfoCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _getStatusColor(trip.status, colorScheme);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(AppSizes.space12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      color: color.withValues(alpha: 0.2),
                    ),
                    child: trip.coverImageUrl != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusSm),
                            child: CachedNetworkImage(
                              imageUrl: trip.coverImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.flight, color: color, size: 28),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.title,
                          style:
                              theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trip.destination != null)
                          Text(
                            trip.destination!,
                            style: theme.textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: theme.hintColor,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space8),
              Row(
                children: [
                  _buildChip(
                    context,
                    _getStatusLabel(trip.status),
                    color,
                  ),
                  const SizedBox(width: AppSizes.space8),
                  Icon(Icons.calendar_today, size: 14, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDate(trip.startDate)} - ${_formatDate(trip.endDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'planned':
        return AppColors.sunnyYellow;
      case 'ongoing':
        return AppColors.oceanTeal;
      case 'completed':
        return AppColors.mintGreen;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'planned':
        return 'Planned';
      case 'ongoing':
        return 'Ongoing';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return date;
    }
  }
}

class MapStatsOverlay extends StatelessWidget {
  final MapState mapState;

  const MapStatsOverlay({super.key, required this.mapState});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Travels',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSizes.space8),
            _buildStatRow(
              context,
              Icons.flight,
              '${mapState.totalTrips} trips',
            ),
            _buildStatRow(
              context,
              Icons.place,
              '${mapState.uniqueDestinations.length} destinations',
            ),
            const Divider(height: AppSizes.space16),
            _buildLegendRow(context, 'Planned', AppColors.sunnyYellow,
                mapState.plannedTrips.length),
            _buildLegendRow(context, 'Ongoing', AppColors.oceanTeal,
                mapState.ongoingTrips.length),
            _buildLegendRow(context, 'Completed', AppColors.mintGreen,
                mapState.completedTrips.length),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.hintColor),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(
      BuildContext context, String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label ($count)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
