import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/presentation/providers/trips_provider.dart';

/// Home — the dashboard.
///
/// Screen 3c of the redesign: greeting, search, quick filters, the next-trip
/// hero, and a rail of recent trips, all under the floating nav.
///
/// The filter chips are a view filter over the trips already loaded, exactly
/// as the prototype behaves; they do not re-query the API.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _chips = ['For you', 'Nearby', 'Cities', 'Mountains'];
  String _chip = _chips.first;

  /// What the status pill says: whichever fact about the user's trips is most
  /// worth knowing right now.
  String _statusLabel(List<TripModel> trips) {
    if (trips.isEmpty) return 'No trips yet';

    final active = trips.where(TripFormat.isActive).length;
    if (active > 0) return active == 1 ? 'On a trip' : '$active trips under way';

    final ahead = trips
        .where((t) => (TripFormat.daysUntil(TripFormat.parse(t.startDate)) ?? -1) > 0)
        .length;
    if (ahead > 0) return ahead == 1 ? '1 trip ahead' : '$ahead trips ahead';

    return '${trips.length} trips logged';
  }

  String? _firstName(String? displayName, String? email) {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;

    final local = email?.split('@').first;
    if (local == null || local.isEmpty) return null;
    return local[0].toUpperCase() + local.substring(1);
  }

  /// The quick filters narrow what is already on screen. "For you" is the
  /// unfiltered view; the rest match against the trip's tags and title, which
  /// is the most the current model supports.
  List<TripModel> _filtered(List<TripModel> trips) {
    if (_chip == _chips.first) return trips;

    final needle = _chip.toLowerCase();
    return trips.where((trip) {
      final tags = trip.tags?.map((t) => t.toLowerCase()) ?? const <String>[];
      return tags.any((t) => t.contains(needle) || needle.contains(t)) ||
          trip.title.toLowerCase().contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final authState = ref.watch(authProvider);
    final tripsState = ref.watch(tripsProvider);

    final user = authState.user;
    final firstName = _firstName(user?.displayName, user?.email);
    final trips = _filtered(tripsState.trips);
    final hero = TripFormat.nextTrip(trips);
    final recent = trips.where((trip) => trip.id != hero?.id).toList();

    return OdysseyScaffold(
      extendBehindNav: true,
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: () => ref.read(tripsProvider.notifier).refresh(),
        child: ListView(
          padding: EdgeInsets.only(bottom: navScrollSpacer(context)),
          children: [
            const SizedBox(height: AppSizes.contentTop),

            // --- top bar ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.screenPadding,
              ),
              child: Row(
                children: [
                  // The mock puts the user's home city here. Odyssey stores
                  // no home location and reverse geocoding would mean
                  // prompting for GPS on first paint just to fill a pill, so
                  // this carries trip status instead — same shape, real data.
                  DotPill(
                    label: _statusLabel(tripsState.trips),
                    onTap: () => context.go(AppRoutes.trips),
                  ),
                  const Spacer(),
                  CircleButton(
                    icon: Icons.notifications_none_rounded,
                    size: AppSizes.circleNotification,
                    onPressed: () => context.push(AppRoutes.notifications),
                    semanticLabel: 'Notifications',
                  ),
                  const SizedBox(width: AppSizes.space10),
                  AvatarCircle(
                    name: firstName ?? user?.email,
                    imageUrl: user?.photoUrl,
                    onTap: () => context.go(AppRoutes.settings),
                  ),
                ],
              ),
            ),

            // --- greeting ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.space26,
                AppSizes.screenPadding,
                0,
              ),
              child: Text(
                firstName == null
                    ? 'Where to\nnext?'
                    : 'Where to\nnext, $firstName?',
                style: AppTypography.heroTitle.copyWith(color: t.ink),
              ),
            ),

            // --- search ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                AppSizes.space22,
                AppSizes.screenPadding,
                0,
              ),
              child: SearchPill(
                hint: 'Search a city or trip',
                readOnly: true,
                onTap: () => context.go(AppRoutes.trips),
              ),
            ),

            // --- quick filters ---
            const SizedBox(height: AppSizes.space18),
            ChipRow(
              labels: _chips,
              selected: _chip,
              onSelected: (value) => setState(() => _chip = value),
            ),

            // --- next trip ---
            if (tripsState.isLoading && tripsState.trips.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.space18,
                  AppSizes.screenPadding,
                  0,
                ),
                child: Skeleton.tile(height: AppSizes.homeHeroHeight),
              )
            else if (hero != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.space18,
                  AppSizes.screenPadding,
                  0,
                ),
                child: _NextTripHero(trip: hero),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.space18,
                  AppSizes.screenPadding,
                  0,
                ),
                child: OdysseyEmptyState(
                  icon: Icons.explore_outlined,
                  message: _chip == _chips.first
                      ? 'No trips yet. The next one starts here.'
                      : 'Nothing matches $_chip.',
                  actionLabel: _chip == _chips.first ? 'Plan a trip' : null,
                  onAction: () => context.push(AppRoutes.createTrip),
                ),
              ),

            // --- recent trips ---
            //
            // While the first load is still running there is nothing to say
            // about how many trips there are, so the strip is drawn as
            // thumbnails-in-waiting rather than left blank. A blank gap and
            // "you have no other trips" look identical, and only one of them
            // is true.
            if (tripsState.isLoading && tripsState.trips.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.space26,
                  AppSizes.screenPadding,
                  0,
                ),
                child: Skeleton(width: 148, height: 19),
              ),
              const SizedBox(height: AppSizes.space14),
              SizedBox(
                height: AppSizes.homeThumbStrip,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  itemCount: 3,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSizes.space12),
                  itemBuilder: (context, _) => const _TripThumbSkeleton(),
                ),
              ),
            ] else if (recent.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.space26,
                  AppSizes.screenPadding,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Recent trips',
                      style: AppTypography.sectionHeading.copyWith(color: t.ink),
                    ),
                    const Spacer(),
                    Pressable(
                      onTap: () => context.go(AppRoutes.trips),
                      borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                      child: Text(
                        'See all',
                        style: AppTypography.caption.copyWith(color: t.ink3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.space14),
              SizedBox(
                height: AppSizes.homeThumbStrip,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPadding,
                  ),
                  itemCount: recent.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSizes.space12),
                  itemBuilder: (context, index) =>
                      _TripThumb(trip: recent[index]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The 320px next-trip card: cover photography, a countdown pill, and the
/// destination set large over the scrim.
class _NextTripHero extends StatelessWidget {
  const _NextTripHero({required this.trip});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final start = TripFormat.parse(trip.startDate);
    final end = TripFormat.parse(trip.endDate);
    final countdown = TripFormat.countdown(start, end);

    return PhotoSurface(
      imageUrl: trip.coverImageUrl,
      seed: trip.id,
      heroTag: 'trip-image-${trip.id}',
      radius: AppSizes.radiusHeroLarge,
      height: AppSizes.homeHeroHeight,
      onTap: () => context.push('${AppRoutes.tripDetail}/${trip.id}', extra: trip),
      child: Stack(
        children: [
          if (countdown != null)
            Positioned(
              right: AppSizes.space16,
              top: AppSizes.space16,
              child: PhotoPill(label: countdown),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.space20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const EyebrowLabel(
                          'Next trip',
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: AppSizes.space8),
                        Text(
                          trip.title,
                          style: AppTypography.heroPlace.copyWith(
                            color: AppColors.onPhoto,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSizes.space8),
                        Text(
                          TripFormat.tripMeta(trip),
                          style: AppTypography.metaLarge.copyWith(
                            color: AppColors.onPhoto2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.space14),
                  // Lime in both themes: this arrow sits on a photograph,
                  // where the light theme's ink fill would disappear.
                  ArrowCircle(
                    brand: true,
                    onTap: () => context.push(
                      '${AppRoutes.tripDetail}/${trip.id}',
                      extra: trip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 150px square cover with the trip's title and meta beneath it.
class _TripThumb extends StatelessWidget {
  const _TripThumb({required this.trip});

  final TripModel trip;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final start = TripFormat.parse(trip.startDate);
    final end = TripFormat.parse(trip.endDate);
    final progress = TripFormat.dayProgress(start, end);

    return SizedBox(
      width: AppSizes.tripThumb,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PhotoSurface(
            imageUrl: trip.coverImageUrl,
            seed: trip.id,
            heroTag: 'trip-image-${trip.id}',
            width: AppSizes.tripThumb,
            height: AppSizes.tripThumb,
            radius: AppSizes.radiusTile,
            scrim: progress != null,
            onTap: () => context.push(
              '${AppRoutes.tripDetail}/${trip.id}',
              extra: trip,
            ),
            child: progress == null
                ? null
                : Positioned(
                    left: AppSizes.space10,
                    bottom: AppSizes.space10,
                    child: OdysseyBadge('DAY ${progress.$1} / ${progress.$2}'),
                  ),
          ),
          const SizedBox(height: AppSizes.space10),
          Text(
            trip.title,
            style: AppTypography.cardTitle.copyWith(color: t.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            TripFormat.tripMeta(trip),
            style: AppTypography.rowMeta.copyWith(color: t.ink3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A [_TripThumb] before its trip has arrived: the same square, the same
/// caption lines, in the same places.
class _TripThumbSkeleton extends StatelessWidget {
  const _TripThumbSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: AppSizes.tripThumb,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Skeleton(
            width: AppSizes.tripThumb,
            height: AppSizes.tripThumb,
            radius: AppSizes.radiusTile,
          ),
          SizedBox(height: AppSizes.space10),
          Skeleton(width: 108, height: 13),
          SizedBox(height: AppSizes.space6),
          Skeleton(width: 68, height: 11),
        ],
      ),
    );
  }
}
