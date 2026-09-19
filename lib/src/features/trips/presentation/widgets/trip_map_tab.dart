import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../activities/data/models/activity_model.dart';
import '../../../activities/presentation/providers/activities_provider.dart';
import '../../../memories/data/models/memory_model.dart';
import '../../../memories/presentation/providers/memories_provider.dart';

/// The trip's own map: its plans and its photos, pinned where they happened.
///
/// Built on the same pins and glass controls as the world map (3g), so the two
/// read as the same surface at different scales.
class TripMapTab extends ConsumerStatefulWidget {
  const TripMapTab({
    super.key,
    required this.tripId,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String tripId;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  ConsumerState<TripMapTab> createState() => _TripMapTabState();
}

class _TripMapTabState extends ConsumerState<TripMapTab> {
  final MapController _mapController = MapController();

  bool _showActivities = true;
  bool _showMemories = true;

  /// What the selected pin card is showing, if anything.
  ({String title, String meta, String? imageUrl, String seed})? _selected;

  void _zoom(double delta) {
    HapticFeedback.selectionClick();
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + delta);
  }

  void _fit(List<LatLng> points) {
    if (points.isEmpty) return;
    HapticFeedback.selectionClick();
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(56),
      ),
    );
  }

  static LatLng _centre(List<LatLng> points) {
    var lat = 0.0;
    var lng = 0.0;
    for (final point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final activities = ref.watch(tripActivitiesProvider(widget.tripId));
    final memories = ref.watch(tripMemoriesProvider(widget.tripId));

    final locatedActivities = activities.activities
        .where((a) => a.latitude != null && a.longitude != null)
        .toList();
    final locatedMemories = memories.memories
        .where((m) => m.latitude != null && m.longitude != null)
        .toList();

    final points = <LatLng>[
      if (_showActivities)
        for (final a in locatedActivities) LatLng(a.latitude!, a.longitude!),
      if (_showMemories)
        for (final m in locatedMemories) LatLng(m.latitude!, m.longitude!),
    ];

    final centre = points.isNotEmpty
        ? _centre(points)
        : LatLng(
            widget.initialLatitude ?? 23.8103,
            widget.initialLongitude ?? 90.4125,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusHero),
      child: SizedBox(
        height: AppSizes.mapHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: t.mapBase,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: centre,
                    initialZoom: points.isEmpty ? 5.0 : 10.0,
                    minZoom: 2.0,
                    maxZoom: 18.0,
                    onTap: (_, _) => setState(() => _selected = null),
                  ),
                  children: [
                    _themedTiles(t),
                    // Required by the OpenStreetMap licence: the tile data is
                    // ODbL and must be credited wherever it is shown.
                    RichAttributionWidget(
                      showFlutterMapAttribution: false,
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/copyright',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ],
                    ),
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 80,
                        size: const Size(44, 44),
                        markers: _markers(locatedActivities, locatedMemories),
                        builder: (context, markers) => _ClusterMark(
                          count: markers.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- filters ---
            Positioned(
              left: AppSizes.space14,
              top: AppSizes.space14,
              right: 70,
              child: Wrap(
                spacing: AppSizes.space8,
                children: [
                  OdysseyChip(
                    label: 'Plans ${locatedActivities.length}',
                    selected: _showActivities,
                    activeStyle: ChipActiveStyle.action,
                    onTap: () =>
                        setState(() => _showActivities = !_showActivities),
                  ),
                  OdysseyChip(
                    label: 'Photos ${locatedMemories.length}',
                    selected: _showMemories,
                    activeStyle: ChipActiveStyle.action,
                    onTap: () => setState(() => _showMemories = !_showMemories),
                  ),
                ],
              ),
            ),

            // --- controls ---
            Positioned(
              right: AppSizes.space14,
              top: AppSizes.space14,
              child: Column(
                children: [
                  SquareButton(
                    glyph: '+',
                    size: 36,
                    onPressed: () => _zoom(1),
                    semanticLabel: 'Zoom in',
                  ),
                  const SizedBox(height: AppSizes.space6),
                  SquareButton(
                    glyph: '−',
                    size: 36,
                    onPressed: () => _zoom(-1),
                    semanticLabel: 'Zoom out',
                  ),
                  const SizedBox(height: AppSizes.space6),
                  SquareButton(
                    icon: Icons.my_location_rounded,
                    size: 36,
                    accent: true,
                    onPressed: () => _fit(points),
                    semanticLabel: 'Fit to pins',
                  ),
                ],
              ),
            ),

            if (_selected != null)
              Positioned(
                left: AppSizes.space14,
                right: AppSizes.space14,
                bottom: AppSizes.space14,
                child: _PinCard(
                  title: _selected!.title,
                  meta: _selected!.meta,
                  imageUrl: _selected!.imageUrl,
                  seed: _selected!.seed,
                  onClose: () => setState(() => _selected = null),
                ),
              )
            else if (points.isEmpty)
              Positioned(
                left: AppSizes.space14,
                right: AppSizes.space14,
                bottom: AppSizes.space14,
                child: GlassBar(
                  radius: AppSizes.radiusCard,
                  padding: const EdgeInsets.all(AppSizes.space16),
                  child: Text(
                    'Nothing pinned yet. Plans and photos with a location '
                    'show up here.',
                    textAlign: TextAlign.center,
                    style: AppTypography.rowMeta.copyWith(color: t.ink2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The same tile treatment as the world map: OSM's light raster tiles,
  /// inverted and desaturated for the dark theme.
  Widget _themedTiles(OdysseyTokens t) {
    final tiles = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.odyssey.app',
    );

    if (!t.isDark) return tiles;

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -0.60, -0.20, -0.05, 0, 225,
        -0.15, -0.65, -0.05, 0, 225,
        -0.10, -0.20, -0.55, 0, 225,
        0, 0, 0, 1, 0,
      ]),
      child: tiles,
    );
  }

  List<Marker> _markers(
    List<ActivityModel> activities,
    List<MemoryModel> memories,
  ) {
    final markers = <Marker>[];

    if (_showActivities) {
      for (final activity in activities) {
        markers.add(
          Marker(
            point: LatLng(activity.latitude!, activity.longitude!),
            width: 44,
            height: 44,
            child: _Pin(
              selected: _selected?.title == activity.title,
              onTap: () {
                HapticFeedback.selectionClick();
                final when = DateTime.tryParse(activity.scheduledTime);
                setState(() {
                  _selected = (
                    title: activity.title,
                    meta: [
                      activity.category,
                      if (when != null) TripFormat.shortDate(when),
                    ].join(' · '),
                    imageUrl: null,
                    seed: activity.id,
                  );
                });
              },
            ),
          ),
        );
      }
    }

    if (_showMemories) {
      for (final memory in memories) {
        markers.add(
          Marker(
            point: LatLng(memory.latitude!, memory.longitude!),
            width: 44,
            height: 44,
            child: _Pin(
              selected: _selected?.seed == memory.id,
              onTap: () {
                HapticFeedback.selectionClick();
                final url = memory.mediaItems.isNotEmpty
                    ? (memory.mediaItems.first.thumbnailUrl ??
                          memory.mediaItems.first.url)
                    : memory.photoUrl;
                setState(() {
                  _selected = (
                    title: memory.caption?.isNotEmpty == true
                        ? memory.caption!
                        : 'Memory',
                    meta: memory.location ?? 'Photo',
                    imageUrl: url,
                    seed: memory.id,
                  );
                });
              },
            ),
          ),
        );
      }
    }

    return markers;
  }
}

/// A pin, matching the world map's: 15px idle, 22px lime when selected, with
/// the only shadow this system has.
class _Pin extends StatelessWidget {
  const _Pin({required this.selected, required this.onTap});

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
                : (t.isDark ? const Color(0xE6F2F2EF) : AppColors.obsidian),
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: AppSizes.pinRing),
            boxShadow: selected ? AppColors.activePinGlow : null,
          ),
        ),
      ),
    );
  }
}

class _ClusterMark extends StatelessWidget {
  const _ClusterMark({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.action,
        shape: BoxShape.circle,
        border: Border.all(
          color: t.isDark ? AppColors.obsidian : Colors.white,
          width: AppSizes.pinRing,
        ),
      ),
      child: Text(
        '$count',
        style: AppTypography.numeral.copyWith(color: t.onAction),
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.title,
    required this.meta,
    required this.imageUrl,
    required this.seed,
    required this.onClose,
  });

  final String title;
  final String meta;
  final String? imageUrl;
  final String seed;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return GlassBar(
      radius: AppSizes.radiusCard,
      blur: AppSizes.glassBlurLight,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          PhotoSurface(
            imageUrl: imageUrl,
            seed: seed,
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
                  title,
                  style: AppTypography.rowTitle.copyWith(color: t.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AppTypography.rowMeta.copyWith(color: t.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space10),
          CircleButton(
            glyph: '✕',
            size: AppSizes.circleSm,
            onPressed: onClose,
            semanticLabel: 'Close',
          ),
        ],
      ),
    );
  }
}
