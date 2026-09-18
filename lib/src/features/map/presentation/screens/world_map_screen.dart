import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/router/app_router.dart';
import '../../../ads/presentation/widgets/watch_ad_to_unlock_button.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../../../subscription/presentation/widgets/temporary_unlock_banner.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../providers/map_provider.dart';
import '../widgets/trip_marker.dart';

class WorldMapScreen extends ConsumerStatefulWidget {
  const WorldMapScreen({super.key});

  @override
  ConsumerState<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends ConsumerState<WorldMapScreen> {
  final MapController _mapController = MapController();
  TripLocation? _selectedTrip;
  bool _showStats = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapState = ref.watch(mapTripsProvider);
    final hasAccess =
        ref.watch(featureAccessProvider(PremiumFeature.worldMap));

    // Show paywall for users without access (free + no active rewarded unlock).
    if (!hasAccess) {
      return _buildPaywallScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('World Map'),
        actions: [
          IconButton(
            icon: Icon(_showStats ? Icons.info : Icons.info_outline),
            onPressed: () {
              setState(() {
                _showStats = !_showStats;
              });
            },
            tooltip: 'Toggle stats',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(mapTripsProvider.notifier).refresh();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      // A temporary unlock looks exactly like Premium until the day it stops
      // working. Saying how long is left turns "it broke" into "it ran out".
      bottomNavigationBar:
          const TemporaryUnlockBanner(feature: PremiumFeature.worldMap),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.0, 0.0),
              initialZoom: 2.0,
              minZoom: 1.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedTrip = null;
                });
              },
            ),
            children: [
              // OpenStreetMap tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.odyssey.app',
              ),
              // Required by the OpenStreetMap licence: the tile data is ODbL and
              // must be credited wherever it is shown.
              RichAttributionWidget(
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ],
              ),
              // Trip markers
              MarkerLayer(
                markers: _buildMarkers(mapState),
              ),
            ],
          ),

          // Loading indicator
          if (mapState.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.space12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: AppSizes.space12),
                        Text('Loading trips...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Error message
          if (mapState.error != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.space12),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: AppSizes.space8),
                      Expanded(
                        child: Text(
                          mapState.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          ref.read(mapTripsProvider.notifier).refresh();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Stats overlay
          if (_showStats && !mapState.isLoading)
            Positioned(
              top: 16,
              left: 16,
              child: MapStatsOverlay(mapState: mapState),
            ),

          // Selected trip info card
          if (_selectedTrip != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Center(
                child: TripInfoCard(
                  trip: _selectedTrip!,
                  onTap: () {
                    context.push('${AppRoutes.tripDetail}/${_selectedTrip!.tripId}');
                  },
                  onClose: () {
                    setState(() {
                      _selectedTrip = null;
                    });
                  },
                ),
              ),
            ),

          // Empty state
          //
          // Keyed on `mappable`, not on the trip list: a user with ten trips and
          // no recorded coordinates has an empty map, and telling them "no trips
          // yet" would be wrong twice over. The message below distinguishes the
          // two cases.
          if (!mapState.isLoading && mapState.mappable.isEmpty)
            Center(
              child: Card(
                margin: const EdgeInsets.all(AppSizes.space24),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.space24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 64,
                        color: theme.hintColor,
                      ),
                      const SizedBox(height: AppSizes.space16),
                      Text(
                        mapState.unmapped.isEmpty
                            ? 'No trips on the map yet'
                            : 'No locations recorded yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSizes.space8),
                      Text(
                        mapState.unmapped.isEmpty
                            ? 'Trips appear here once their memories have a location'
                            : '${mapState.unmapped.length} '
                                '${mapState.unmapped.length == 1 ? 'trip has' : 'trips have'} '
                                'no location yet. Add a photo with a place to one '
                                'of its memories and it will appear here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.space16),
                      if (mapState.unmapped.isEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push(AppRoutes.createTrip);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Trip'),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push('${AppRoutes.tripDetail}/'
                                '${mapState.unmapped.first.tripId}');
                          },
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Add a location'),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Zoom controls
          Positioned(
            right: 16,
            bottom: _selectedTrip != null ? 140 : 24,
            child: Column(
              children: [
                _buildZoomButton(Icons.add, () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    currentZoom + 1,
                  );
                }),
                const SizedBox(height: AppSizes.space8),
                _buildZoomButton(Icons.remove, () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    currentZoom - 1,
                  );
                }),
                const SizedBox(height: AppSizes.space16),
                _buildZoomButton(Icons.my_location, () {
                  // Reset to world view
                  _mapController.move(const LatLng(20.0, 0.0), 2.0);
                }),
              ],
            ),
          ),

          // Legend
          Positioned(
            bottom: _selectedTrip != null ? 140 : 24,
            left: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.space8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLegendItem('Planned', AppColors.sunnyYellow),
                    _buildLegendItem('Ongoing', AppColors.oceanTeal),
                    _buildLegendItem('Completed', AppColors.mintGreen),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(MapState mapState) {
    // `mappable`, not `tripLocations`: trips with no recorded location are kept
    // in the state now so the map can account for them, and the force-unwraps
    // below would throw on the first one.
    return mapState.mappable.map((trip) {
      final isSelected = _selectedTrip?.tripId == trip.tripId;
      return Marker(
        point: LatLng(trip.latitude!, trip.longitude!),
        width: isSelected ? 50 : 40,
        height: isSelected ? 50 : 40,
        child: TripMarker(
          trip: trip,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedTrip = trip;
            });
            // Animate to the selected marker
            _mapController.move(
              LatLng(trip.latitude!, trip.longitude!),
              _mapController.camera.zoom < 4 ? 4 : _mapController.camera.zoom,
            );
          },
        ),
      );
    }).toList();
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(icon, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywallScreen(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('World Map'),
      ),
      body: Stack(
        children: [
          // Blurred preview map
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(20.0, 0.0),
              initialZoom: 2.0,
              interactionOptions: InteractionOptions(flags: 0), // Disable interaction
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.odyssey.app',
              ),
            ],
          ),
          // Blur overlay
          Container(
            color: colorScheme.surface.withValues(alpha: 0.8),
          ),
          // The tiles are still on screen behind the blur, so they still need
          // crediting. Plain text rather than RichAttributionWidget: that widget
          // reads MapController from its context, so it only works inside a
          // FlutterMap - where the blur would render it unreadable anyway.
          Positioned(
            right: 8,
            bottom: 8,
            child: GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                '© OpenStreetMap contributors',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          // Premium prompt
          Center(
            child: Container(
              margin: const EdgeInsets.all(AppSizes.space24),
              padding: const EdgeInsets.all(AppSizes.space24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.sunnyYellow, AppColors.goldenGlow],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.map,
                      color: colorScheme.onSurface,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),
                  Text(
                    'World Map',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space8),
                  Text(
                    'See your trips on an interactive world map, placed by the locations recorded on your memories.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.space24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => PaywallUtils.showPaywall(
                        context,
                        featureName: 'World Map',
                        featureIcon: Icons.map,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.sunnyYellow,
                        foregroundColor: AppColors.charcoal,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.space16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                        ),
                      ),
                      child: const Text(
                        'Upgrade to Premium',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space12),
                  // Free alternative: watch a rewarded ad for 24h access.
                  const WatchAdToUnlockButton(feature: PremiumFeature.worldMap),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
