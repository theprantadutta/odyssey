import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../activities/data/models/activity_model.dart';
import '../../../activities/presentation/providers/activities_provider.dart';
import '../../../memories/data/models/memory_model.dart';
import '../../../memories/presentation/providers/memories_provider.dart';

/// Map tab showing activities and memories for a trip
class TripMapTab extends ConsumerStatefulWidget {
  final String tripId;
  final double? initialLatitude;
  final double? initialLongitude;

  const TripMapTab({
    super.key,
    required this.tripId,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  ConsumerState<TripMapTab> createState() => _TripMapTabState();
}

class _TripMapTabState extends ConsumerState<TripMapTab> {
  final MapController _mapController = MapController();
  bool _showActivities = true;
  bool _showMemories = true;

  @override
  Widget build(BuildContext context) {
    final activitiesState = ref.watch(tripActivitiesProvider(widget.tripId));
    final memoriesState = ref.watch(tripMemoriesProvider(widget.tripId));

    // Calculate bounds for the map
    final allPoints = <LatLng>[];

    if (_showActivities) {
      for (final activity in activitiesState.activities) {
        if (activity.latitude != null && activity.longitude != null) {
          final lat = double.tryParse(activity.latitude!);
          final lng = double.tryParse(activity.longitude!);
          if (lat != null && lng != null) {
            allPoints.add(LatLng(lat, lng));
          }
        }
      }
    }

    if (_showMemories) {
      for (final memory in memoriesState.memories) {
        final lat = double.tryParse(memory.latitude);
        final lng = double.tryParse(memory.longitude);
        if (lat != null && lng != null) {
          allPoints.add(LatLng(lat, lng));
        }
      }
    }

    // Default center if no points
    final defaultCenter = LatLng(
      widget.initialLatitude ?? 23.8103,
      widget.initialLongitude ?? 90.4125,
    );

    final center = allPoints.isNotEmpty
        ? _calculateCenter(allPoints)
        : defaultCenter;

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: allPoints.isEmpty ? 5.0 : 10.0,
            minZoom: 2.0,
            maxZoom: 18.0,
            onTap: (tapPosition, point) {
              // Dismiss any bottom sheet
            },
          ),
          children: [
            // OpenStreetMap tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.odyssey.app',
            ),
            // Marker cluster layer
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 80,
                size: const Size(50, 50),
                markers: _buildMarkers(
                  activitiesState.activities,
                  memoriesState.memories,
                ),
                builder: (context, markers) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.sunnyYellow,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      boxShadow: AppSizes.softShadow,
                    ),
                    child: Center(
                      child: Text(
                        '${markers.length}',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        // Filter toggles
        Positioned(
          top: AppSizes.space16,
          right: AppSizes.space16,
          child: _buildFilterToggles(
            activitiesState.activities.length,
            memoriesState.memories.length,
          ),
        ),

        // Legend
        Positioned(
          bottom: AppSizes.space16,
          left: AppSizes.space16,
          child: _buildLegend(),
        ),

        // Zoom controls
        Positioned(
          bottom: AppSizes.space16,
          right: AppSizes.space16,
          child: _buildZoomControls(),
        ),

        // Empty state overlay
        if (allPoints.isEmpty &&
            !activitiesState.isLoading &&
            !memoriesState.isLoading)
          _buildEmptyOverlay(),
      ],
    );
  }

  List<Marker> _buildMarkers(
    List<ActivityModel> activities,
    List<MemoryModel> memories,
  ) {
    final markers = <Marker>[];

    // Activity markers
    if (_showActivities) {
      for (final activity in activities) {
        if (activity.latitude != null && activity.longitude != null) {
          final lat = double.tryParse(activity.latitude!);
          final lng = double.tryParse(activity.longitude!);
          if (lat != null && lng != null) {
            markers.add(
              Marker(
                point: LatLng(lat, lng),
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showActivityDetails(activity);
                  },
                  child: _buildActivityMarker(activity),
                ),
              ),
            );
          }
        }
      }
    }

    // Memory markers
    if (_showMemories) {
      for (final memory in memories) {
        final lat = double.tryParse(memory.latitude);
        final lng = double.tryParse(memory.longitude);
        if (lat != null && lng != null) {
          markers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showMemoryDetails(memory);
                },
                child: _buildMemoryMarker(memory),
              ),
            ),
          );
        }
      }
    }

    return markers;
  }

  Widget _buildActivityMarker(ActivityModel activity) {
    final color = _getCategoryColor(activity.category);
    final icon = _getCategoryIcon(activity.category);

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppSizes.softShadow,
      ),
      child: Center(
        child: Icon(
          icon,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMemoryMarker(MemoryModel memory) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.sunnyYellow, width: 3),
        boxShadow: AppSizes.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: CachedNetworkImage(
          imageUrl: memory.photoUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: AppColors.warmGray,
            child: const Icon(
              Icons.photo_rounded,
              color: AppColors.mutedGray,
              size: 20,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppColors.warmGray,
            child: const Icon(
              Icons.broken_image_rounded,
              color: AppColors.mutedGray,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterToggles(int activityCount, int memoryCount) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        children: [
          _buildFilterChip(
            label: 'Activities',
            count: activityCount,
            isEnabled: _showActivities,
            color: AppColors.oceanTeal,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showActivities = !_showActivities);
            },
          ),
          const Divider(height: 1),
          _buildFilterChip(
            label: 'Memories',
            count: memoryCount,
            isEnabled: _showMemories,
            color: AppColors.sunnyYellow,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showMemories = !_showMemories);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isEnabled,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isEnabled ? color : AppColors.warmGray,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isEnabled ? color : AppColors.mutedGray,
                  width: 2,
                ),
              ),
              child: isEnabled
                  ? const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '$label ($count)',
              style: AppTypography.caption.copyWith(
                color: isEnabled ? AppColors.charcoal : AppColors.mutedGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: AppColors.snowWhite.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLegendItem(
            color: AppColors.coralBurst,
            icon: Icons.restaurant_rounded,
            label: 'Food',
          ),
          const SizedBox(height: AppSizes.space4),
          _buildLegendItem(
            color: AppColors.skyBlue,
            icon: Icons.flight_rounded,
            label: 'Travel',
          ),
          const SizedBox(height: AppSizes.space4),
          _buildLegendItem(
            color: AppColors.lavenderDream,
            icon: Icons.hotel_rounded,
            label: 'Stay',
          ),
          const SizedBox(height: AppSizes.space4),
          _buildLegendItem(
            color: AppColors.oceanTeal,
            icon: Icons.explore_rounded,
            label: 'Explore',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Center(
            child: Icon(icon, size: 12, color: Colors.white),
          ),
        ),
        const SizedBox(width: AppSizes.space8),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom + 1,
              );
            },
            icon: const Icon(Icons.add_rounded),
            color: AppColors.charcoal,
            iconSize: 24,
          ),
          const Divider(height: 1),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final currentZoom = _mapController.camera.zoom;
              _mapController.move(
                _mapController.camera.center,
                currentZoom - 1,
              );
            },
            icon: const Icon(Icons.remove_rounded),
            color: AppColors.charcoal,
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppSizes.space32),
          padding: const EdgeInsets.all(AppSizes.space24),
          decoration: BoxDecoration(
            color: AppColors.snowWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            boxShadow: AppSizes.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.space16),
                decoration: BoxDecoration(
                  color: AppColors.lemonLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Icon(
                  Icons.map_rounded,
                  size: 40,
                  color: AppColors.goldenGlow,
                ),
              ),
              const SizedBox(height: AppSizes.space16),
              Text(
                'No Locations Yet',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.charcoal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.space8),
              Text(
                'Add activities or memories with location data to see them on the map.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.slate,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActivityDetails(ActivityModel activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(AppSizes.space16),
        padding: const EdgeInsets.all(AppSizes.space20),
        decoration: BoxDecoration(
          color: AppColors.snowWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category badge and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSizes.space8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(activity.category),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Icon(
                    _getCategoryIcon(activity.category),
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        activity.category.toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: _getCategoryColor(activity.category),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (activity.description != null &&
                activity.description!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.space12),
              Text(
                activity.description!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.slate,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSizes.space16),
            // Info row
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: AppColors.mutedGray,
                ),
                const SizedBox(width: AppSizes.space4),
                Text(
                  activity.scheduledTime,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(width: AppSizes.space16),
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.mutedGray,
                ),
                const SizedBox(width: AppSizes.space4),
                Expanded(
                  child: Text(
                    '${activity.latitude ?? 'N/A'}, ${activity.longitude ?? 'N/A'}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slate,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMemoryDetails(MemoryModel memory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: AppColors.snowWhite,
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusXl),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: memory.photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.warmGray,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.sunnyYellow,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.warmGray,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.mutedGray,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            // Details
            Padding(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (memory.caption != null && memory.caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.space12),
                      child: Text(
                        memory.caption!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.charcoal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.mutedGray,
                      ),
                      const SizedBox(width: AppSizes.space4),
                      Expanded(
                        child: Text(
                          '${memory.latitude}, ${memory.longitude}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.slate,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (memory.takenAt != null) ...[
                        const SizedBox(width: AppSizes.space16),
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppColors.mutedGray,
                        ),
                        const SizedBox(width: AppSizes.space4),
                        Text(
                          memory.takenAt!.split('T').first,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.slate,
                          ),
                        ),
                      ],
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

  LatLng _calculateCenter(List<LatLng> points) {
    double lat = 0;
    double lng = 0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return AppColors.coralBurst;
      case 'travel':
        return AppColors.skyBlue;
      case 'stay':
        return AppColors.lavenderDream;
      case 'explore':
      default:
        return AppColors.oceanTeal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'travel':
        return Icons.flight_rounded;
      case 'stay':
        return Icons.hotel_rounded;
      case 'explore':
      default:
        return Icons.explore_rounded;
    }
  }
}
