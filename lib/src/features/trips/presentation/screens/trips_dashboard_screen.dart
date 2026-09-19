import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../common/widgets/sync_status_indicator.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/task_routes.dart';
import '../../../notifications/presentation/widgets/notification_permission_prompt.dart';
import '../../../walkthrough/presentation/providers/walkthrough_provider.dart';
import '../../../walkthrough/presentation/steps/dashboard_walkthrough_steps.dart';
import '../../../walkthrough/presentation/widgets/walkthrough_overlay.dart';
import '../../data/models/trip_model.dart';
import '../providers/trips_provider.dart';
import '../widgets/trip_list_card.dart';
import 'trip_form_screen.dart';

/// Trips — the full list, and the second tab.
///
/// The design does not draw this screen, so it is built from the system the
/// rest of the redesign establishes: the screen title set large, a search
/// pill, status chips, and the wide cover cards that are the full-width
/// sibling of the thumbs on Home.
class TripsDashboardScreen extends ConsumerStatefulWidget {
  const TripsDashboardScreen({super.key});

  @override
  ConsumerState<TripsDashboardScreen> createState() =>
      _TripsDashboardScreenState();
}

class _TripsDashboardScreenState extends ConsumerState<TripsDashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Walkthrough anchors.
  final _headerKey = GlobalKey();
  final _notificationKey = GlobalKey();
  final _moreMenuKey = GlobalKey();
  final _searchBarKey = GlobalKey();
  final _quickFiltersKey = GlobalKey();
  final _fabKey = GlobalKey();

  String _status = TripStatusChips.labels.first;

  /// One sheet at a time. Creating a trip while the startup check is still
  /// counting down would otherwise queue a second one behind the first.
  bool _askingAboutNotifications = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        ref
            .read(walkthroughProvider.notifier)
            .startIfNeeded(
              'dashboard',
              DashboardWalkthroughSteps.build(
                headerKey: _headerKey,
                notificationKey: _notificationKey,
                moreMenuKey: _moreMenuKey,
                searchBarKey: _searchBarKey,
                quickFiltersKey: _quickFiltersKey,
                fabKey: _fabKey,
              ),
            );
      });
    });

    _maybeAskAboutNotifications(occasion: 'dashboard-with-trips');
  }

  /// Raises notifications once the person has a trip for them to be about.
  ///
  /// Deliberately not at launch, and deliberately not on an empty dashboard.
  /// The system permission dialog can be shown once, so the moment it is spent
  /// decides the answer forever — and "would you like reminders" means nothing
  /// to someone who has not yet made the thing that would be reminded about.
  ///
  /// The wait is longer than the walkthrough's so the two cannot overlap; a
  /// coach mark and a bottom sheet competing for the same screen is how people
  /// dismiss both without reading either.
  Future<void> _maybeAskAboutNotifications({
    required String occasion,
    Duration delay = const Duration(milliseconds: 2500),
  }) async {
    if (_askingAboutNotifications) return;
    _askingAboutNotifications = true;

    try {
      await Future<void>.delayed(delay);
      if (!mounted) return;

      final trips = ref.read(tripsProvider).trips;
      if (trips.isEmpty) return;

      if (ref.read(walkthroughProvider).isActive) return;
      if (!mounted) return;

      await maybeAskAboutNotifications(context, ref, occasion: occasion);
    } finally {
      _askingAboutNotifications = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(tripsProvider.notifier).loadMore();
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(tripsProvider.notifier).refresh();
  }

  void _handleCreateTrip() {
    HapticFeedback.lightImpact();
    context.push(AppRoutes.createTrip).then((_) {
      ref.read(tripsProvider.notifier).refresh();
    });
  }

  void _handleTripTap(TripModel trip) {
    HapticFeedback.selectionClick();
    context.push('${AppRoutes.tripDetail}/${trip.id}', extra: trip);
  }

  void _handleEditTrip(TripModel trip) {
    HapticFeedback.lightImpact();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            settings: TaskRoutes.settings(TaskRoutes.tripForm),
            builder: (context) => TripFormScreen(trip: trip),
          ),
        )
        .then((_) => ref.read(tripsProvider.notifier).refresh());
  }

  Future<void> _handleTripLongPress(TripModel trip) async {
    HapticFeedback.mediumImpact();
    final action = await showOdysseyPicker<String>(
      context: context,
      title: trip.title,
      options: const ['Edit trip', 'Delete trip'],
      labelOf: (value) => value,
    );

    if (!mounted || action == null) return;
    if (action == 'Edit trip') {
      _handleEditTrip(trip);
    } else {
      await _handleDeleteTrip(trip.id, trip.title);
    }
  }

  Future<void> _handleDeleteTrip(String tripId, String title) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete trip',
      body: [
        'This permanently deletes "$title" and everything in it — activities, '
            'packing list, expenses, documents and memories.',
        'This cannot be undone.',
      ],
      confirmLabel: 'Delete trip',
    );

    if (!confirmed || !mounted) return;

    try {
      await ref.read(tripsProvider.notifier).deleteTrip(tripId);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showOdysseyMessage(context, 'Trip deleted.');
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyMessage(context, 'Could not delete that trip: $e');
    }
  }

  /// The status chips filter what is already loaded. Search goes to the
  /// provider, because it is a server-side query with paging behind it.
  List<TripModel> _visible(List<TripModel> trips) {
    if (_status == TripStatusChips.labels.first) return trips;
    return trips.where((t) => _statusOf(t) == _status).toList();
  }

  String _statusOf(TripModel trip) {
    if (TripFormat.isActive(trip)) return 'Ongoing';
    final days = TripFormat.daysUntil(TripFormat.parse(trip.startDate));
    if (days != null && days > 0) return 'Planned';
    return 'Completed';
  }

  Map<String, int> _counts(List<TripModel> trips) {
    final counts = {for (final label in TripStatusChips.labels) label: 0};
    counts[TripStatusChips.labels.first] = trips.length;
    for (final trip in trips) {
      final key = _statusOf(trip);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(tripsProvider);
    final visible = _visible(state.trips);

    final scaffold = OdysseyScaffold(
        extendBehindNav: true,
        body: RefreshIndicator(
          color: t.action,
          backgroundColor: Color.alphaBlend(t.card, t.canvas),
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.screenPadding,
                    AppSizes.contentTop,
                    AppSizes.screenPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        key: _headerKey,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              'Your\ntrips',
                              style: AppTypography.heroTitle.copyWith(
                                color: t.ink,
                              ),
                            ),
                          ),
                          const SyncStatusIndicator(),
                          const SizedBox(width: AppSizes.space10),
                          CircleButton(
                            key: _fabKey,
                            glyph: '+',
                            style: CircleStyle.action,
                            onPressed: _handleCreateTrip,
                            semanticLabel: 'New trip',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.space22),
                      SearchPill(
                        key: _searchBarKey,
                        hint: 'Search a city or trip',
                        controller: _searchController,
                        onChanged: (value) => ref
                            .read(tripsProvider.notifier)
                            .search(value.isEmpty ? null : value),
                      ),
                      const SizedBox(height: AppSizes.space18),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _quickFiltersKey,
                  child: TripStatusChips(
                    selected: _status,
                    counts: _counts(state.trips),
                    onSelected: (value) => setState(() => _status = value),
                  ),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.space18,
                  AppSizes.screenPadding,
                  navScrollSpacer(context),
                ),
                sliver: _buildList(state, visible),
              ),
            ],
          ),
        ),
    );

    // The coach marks paint over the whole screen, so they sit beside the
    // scaffold rather than wrapping it.
    return Stack(
      children: [
        scaffold,
        Consumer(
          builder: (context, ref, _) {
            final wt = ref.watch(walkthroughProvider);
            if (!wt.isActive || wt.activeSegmentId != 'dashboard') {
              return const SizedBox.shrink();
            }
            return WalkthroughOverlay(
              steps: wt.steps,
              currentIndex: wt.currentStepIndex,
              onNext: () => ref.read(walkthroughProvider.notifier).next(),
              onPrevious: () =>
                  ref.read(walkthroughProvider.notifier).previous(),
              onSkip: () => ref.read(walkthroughProvider.notifier).skip(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildList(TripsState state, List<TripModel> visible) {
    if (state.isLoading && state.trips.isEmpty) {
      return const SliverToBoxAdapter(child: TripListSkeleton());
    }

    if (state.error != null && state.trips.isEmpty) {
      return SliverToBoxAdapter(
        child: OdysseyErrorState(
          message: state.error!,
          onRetry: () => ref.read(tripsProvider.notifier).refresh(),
        ),
      );
    }

    if (visible.isEmpty) {
      final filtered =
          _status != TripStatusChips.labels.first ||
          _searchController.text.isNotEmpty;
      return SliverToBoxAdapter(
        child: OdysseyEmptyState(
          message: filtered
              ? 'Nothing here under that filter.'
              : 'No trips yet. The next one starts here.',
          actionLabel: filtered ? 'Show all trips' : 'Plan a trip',
          onAction: filtered
              ? () {
                  setState(() => _status = TripStatusChips.labels.first);
                  _searchController.clear();
                  ref.read(tripsProvider.notifier).search(null);
                }
              : _handleCreateTrip,
        ),
      );
    }

    return SliverList.separated(
      itemCount: visible.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.space12),
      itemBuilder: (context, index) {
        if (index >= visible.length) {
          return const Skeleton(
            width: double.infinity,
            height: 210,
            radius: AppSizes.radiusHero,
          );
        }
        final trip = visible[index];
        return TripListCard(
          trip: trip,
          onTap: () => _handleTripTap(trip),
          onLongPress: () => _handleTripLongPress(trip),
        );
      },
    );
  }
}
