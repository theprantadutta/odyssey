import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../../../subscription/presentation/widgets/temporary_unlock_banner.dart';
import '../providers/map_provider.dart';

/// Map & memories — screen 3g.
///
/// The map fills the screen with floating glass controls over it; selecting a
/// pin swaps the card at the foot. Pins are 15px idle and 22px lime when
/// selected, with the one shadow this system allows.
class WorldMapScreen extends ConsumerStatefulWidget {
  const WorldMapScreen({super.key});

  @override
  ConsumerState<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends ConsumerState<WorldMapScreen> {
  final MapController _mapController = MapController();
  TripLocation? _selected;

  /// The dark and light tile sets. OpenStreetMap's standard raster tiles are
  /// light, so the dark theme inverts and desaturates them rather than pulling
  /// in a second tile provider — which keeps attribution and caching the same.
  static const String _tileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  void _zoom(double delta) {
    HapticFeedback.selectionClick();
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _fitToTrips(List<TripLocation> locations) {
    final located = locations.where((l) => l.hasLocation).toList();
    if (located.isEmpty) return;

    HapticFeedback.selectionClick();
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: located
            .map((l) => LatLng(l.latitude!, l.longitude!))
            .toList(),
        padding: const EdgeInsets.all(64),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(mapTripsProvider);
    final hasAccess = ref.watch(featureAccessProvider(PremiumFeature.worldMap));

    if (!hasAccess) return _buildPaywall(context);

    final located = state.tripLocations.where((l) => l.hasLocation).toList();

    return Scaffold(
      backgroundColor: t.canvas,
      extendBody: true,
      // A temporary unlock looks exactly like Pro until the day it stops
      // working. Saying how long is left turns "it broke" into "it ran out".
      bottomNavigationBar:
          const TemporaryUnlockBanner(feature: PremiumFeature.worldMap),
      body: Stack(
        children: [
          Positioned.fill(
            child: _MapCanvas(
              controller: _mapController,
              tileUrl: _tileUrl,
              locations: located,
              selected: _selected,
              onSelect: (trip) => setState(() => _selected = trip),
              onClearSelection: () => setState(() => _selected = null),
            ),
          ),

          // --- header ---
          Positioned(
            left: AppSizes.screenPadding,
            right: AppSizes.screenPadding,
            top: 58,
            child: Row(
              children: [
                Expanded(
                  child: GlassBar(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Where you have been',
                            style: AppTypography.caption.copyWith(color: t.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${located.length}',
                          style: AppTypography.numeral.copyWith(color: t.ink3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- controls ---
          Positioned(
            right: 18,
            top: 120,
            child: Column(
              children: [
                SquareButton(
                  glyph: '+',
                  onPressed: () => _zoom(1),
                  semanticLabel: 'Zoom in',
                ),
                const SizedBox(height: AppSizes.space8),
                SquareButton(
                  glyph: '−',
                  onPressed: () => _zoom(-1),
                  semanticLabel: 'Zoom out',
                ),
                const SizedBox(height: AppSizes.space8),
                SquareButton(
                  icon: Icons.my_location_rounded,
                  accent: true,
                  onPressed: () => _fitToTrips(state.tripLocations),
                  semanticLabel: 'Fit to trips',
                ),
              ],
            ),
          ),

          // --- selected pin card ---
          if (_selected != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: AppSizes.space12 + navBarHeight(context),
              child: _SelectedPinCard(
                trip: _selected!,
                onOpen: () => context.push(
                  '${AppRoutes.tripDetail}/${_selected!.tripId}',
                ),
                onClose: () => setState(() => _selected = null),
              ),
            ),

          if (state.isLoading && state.tripLocations.isEmpty)
            Positioned(
              left: AppSizes.screenPadding,
              right: AppSizes.screenPadding,
              bottom: AppSizes.space12 + navBarHeight(context),
              child: GlassBar(
                radius: AppSizes.radiusCard,
                padding: const EdgeInsets.all(AppSizes.space16),
                child: Text(
                  'Finding your trips…',
                  textAlign: TextAlign.center,
                  style: AppTypography.rowMeta.copyWith(color: t.ink2),
                ),
              ),
            )
          else if (located.isEmpty && _selected == null)
            Positioned(
              left: AppSizes.screenPadding,
              right: AppSizes.screenPadding,
              bottom: AppSizes.space12 + navBarHeight(context),
              child: GlassBar(
                radius: AppSizes.radiusCard,
                padding: const EdgeInsets.all(AppSizes.space18),
                child: Text(
                  'No trip on the map yet. Give one a destination and it '
                  'lands here.',
                  textAlign: TextAlign.center,
                  style: AppTypography.rowMeta.copyWith(color: t.ink2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaywall(BuildContext context) {
    final t = context.odyssey;

    return Scaffold(
      backgroundColor: t.canvas,
      body: Stack(
        children: [
          // The map is shown behind, unusable, so what is being offered is
          // visible rather than described.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: _MapCanvas(
                  controller: MapController(),
                  tileUrl: _tileUrl,
                  locations: const [],
                  selected: null,
                  onSelect: (_) {},
                  onClearSelection: () {},
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSizes.screenPadding,
            right: AppSizes.screenPadding,
            bottom: AppSizes.space16 + navBarHeight(context),
            child: OdysseyCard(
              radius: AppSizes.radiusHero,
              padding: const EdgeInsets.all(AppSizes.space20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EyebrowLabel('Pro'),
                  const SizedBox(height: AppSizes.space12),
                  Text(
                    'The world map',
                    style: AppTypography.statSmall.copyWith(color: t.ink),
                  ),
                  const SizedBox(height: AppSizes.space10),
                  Text(
                    'Every trip you have taken, pinned where it happened.',
                    style: AppTypography.subtitle.copyWith(color: t.ink2),
                  ),
                  const SizedBox(height: AppSizes.space18),
                  PillButton(
                    label: 'See Pro',
                    onPressed: () => context.push(AppRoutes.subscription),
                  ),
                ],
              ),
            ),
          ),
          // No back button: this is a tab root, so there is nothing to pop.
        ],
      ),
    );
  }
}

/// The map itself, with the tiles tuned to the theme.
class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.controller,
    required this.tileUrl,
    required this.locations,
    required this.selected,
    required this.onSelect,
    required this.onClearSelection,
  });

  final MapController controller;
  final String tileUrl;
  final List<TripLocation> locations;
  final TripLocation? selected;
  final ValueChanged<TripLocation> onSelect;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    Widget tiles = TileLayer(
      urlTemplate: tileUrl,
      userAgentPackageName: 'com.odyssey.app',
    );

    // OSM's standard tiles are light. Inverting and desaturating them gives a
    // dark map without a second tile source, which keeps one attribution and
    // one cache. The hue rotation puts the greens and blues back the right way
    // round after the inversion.
    if (t.isDark) {
      tiles = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          -0.60, -0.20, -0.05, 0, 225,
          -0.15, -0.65, -0.05, 0, 225,
          -0.10, -0.20, -0.55, 0, 225,
          0, 0, 0, 1, 0,
        ]),
        child: tiles,
      );
    }

    return ColoredBox(
      color: t.mapBase,
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: const LatLng(20.0, 0.0),
          initialZoom: 2.0,
          onTap: (_, _) => onClearSelection(),
        ),
        children: [
          tiles,
          MarkerLayer(
            markers: [
              for (final trip in locations)
                Marker(
                  point: LatLng(trip.latitude!, trip.longitude!),
                  width: 44,
                  height: 44,
                  child: _MapPin(
                    selected: selected?.tripId == trip.tripId,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSelect(trip);
                    },
                  ),
                ),
            ],
          ),
          RichAttributionWidget(
            showFlutterMapAttribution: false,
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(
                  Uri.parse('https://openstreetmap.org/copyright'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pin. Idle is a small pale disc with a ring in the canvas-inverse colour;
/// selected grows to 22px, turns lime, and gains the one shadow in the system.
class _MapPin extends StatelessWidget {
  const _MapPin({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final ring = t.isDark ? AppColors.obsidian : Colors.white;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: AppSizes.durationPin,
          curve: AppSizes.curveState,
          width: selected ? AppSizes.pinSelected : AppSizes.pinIdle,
          height: selected ? AppSizes.pinSelected : AppSizes.pinIdle,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : (t.isDark
                      ? const Color(0xE6F2F2EF)
                      : AppColors.obsidian),
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: AppSizes.pinRing),
            boxShadow: selected ? AppColors.activePinGlow : null,
          ),
        ),
      ),
    );
  }
}

/// The card that swaps to whichever pin is selected.
class _SelectedPinCard extends StatelessWidget {
  const _SelectedPinCard({
    required this.trip,
    required this.onOpen,
    required this.onClose,
  });

  final TripLocation trip;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final start = TripFormat.parse(trip.startDate);
    final end = TripFormat.parse(trip.endDate);

    return GlassBar(
      radius: AppSizes.radiusCard,
      blur: AppSizes.glassBlurLight,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          PhotoSurface(
            imageUrl: trip.coverImageUrl,
            seed: trip.tripId,
            width: 48,
            height: 48,
            radius: AppSizes.radiusChip,
            scrim: false,
          ),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trip.title,
                  style: AppTypography.rowTitle.copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (trip.destination != null &&
                        trip.destination!.isNotEmpty)
                      trip.destination!,
                    TripFormat.dateRange(start, end),
                  ].join(' · '),
                  style: AppTypography.rowMeta.copyWith(color: t.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space10),
          ArrowCircle(size: AppSizes.circleAction, onTap: onOpen),
        ],
      ),
    );
  }
}
