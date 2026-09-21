import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/task_routes.dart';
import '../../../activities/presentation/providers/activities_provider.dart';
import '../../../packing/presentation/providers/packing_provider.dart';
import '../../../sharing/presentation/widgets/collaboration_indicator.dart';
import '../../../sharing/presentation/widgets/share_trip_dialog.dart';
import '../../../templates/presentation/widgets/save_as_template_dialog.dart';
import '../../../walkthrough/presentation/providers/walkthrough_provider.dart';
import '../../../walkthrough/presentation/steps/trip_detail_walkthrough_steps.dart';
import '../../../walkthrough/presentation/widgets/walkthrough_overlay.dart';
import '../../data/models/trip_model.dart';
import '../providers/trips_provider.dart';
import '../widgets/trip_activities_tab.dart';
import '../widgets/trip_documents_tab.dart';
import '../widgets/trip_expenses_tab.dart';
import '../widgets/trip_map_tab.dart';
import '../widgets/trip_memories_tab.dart';
import '../widgets/trip_overview_tab.dart';
import '../widgets/trip_packing_tab.dart';
import 'trip_form_screen.dart';

/// Trip detail — screen 3e.
///
/// A 420px full-bleed cover with the place name set very large over the scrim,
/// then a sheet that overlaps it by 26px carrying the stat row, the segmented
/// control and the panels.
///
/// The design draws three tabs. Odyssey has seven panels of real
/// functionality, so the control keeps its shape and scrolls rather than
/// dropping any of them.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  final String tripId;
  final TripModel? initialTrip;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  static const List<String> _tabs = [
    'Overview',
    'Plan',
    'Packing',
    'Spend',
    'Documents',
    'Memories',
    'Map',
  ];

  final ScrollController _scrollController = ScrollController();
  TripModel? _currentTrip;
  String _tab = _tabs.first;

  // Walkthrough anchors.
  final _heroHeaderKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  final _moreOptionsKey = GlobalKey();
  final _tabBarKey = GlobalKey();
  final _tabContentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Use the trip we were handed immediately, so the cover is painted before
    // the fetch resolves and the Hero has something to fly to.
    _currentTrip = widget.initialTrip;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        ref
            .read(walkthroughProvider.notifier)
            .startIfNeeded(
              'trip_detail',
              TripDetailWalkthroughSteps.build(
                heroHeaderKey: _heroHeaderKey,
                shareButtonKey: _shareButtonKey,
                moreOptionsKey: _moreOptionsKey,
                tabBarKey: _tabBarKey,
                tabContentKey: _tabContentKey,
              ),
            );
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Actions
  // ------------------------------------------------------------------

  void _handleEdit(TripModel trip) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            settings: TaskRoutes.settings(TaskRoutes.tripForm),
            builder: (context) => TripFormScreen(trip: trip),
          ),
        )
        .then((_) => ref.invalidate(tripProvider(trip.id)));
  }

  void _handleShare(TripModel trip) {
    HapticFeedback.lightImpact();
    showDialog<void>(
      context: context,
      builder: (context) =>
          ShareTripDialog(tripId: trip.id, tripTitle: trip.title),
    );
  }

  void _openShares(TripModel trip) {
    context.push(
      '${AppRoutes.tripDetail}/${trip.id}/shares'
      '?title=${Uri.encodeComponent(trip.title)}',
    );
  }

  Future<void> _showOptions(TripModel trip) async {
    HapticFeedback.lightImpact();
    final action = await showOdysseyPicker<String>(
      context: context,
      title: 'Trip options',
      options: const [
        'Edit trip',
        'Manage sharing',
        'Save as template',
        'Delete trip',
      ],
      labelOf: (value) => value,
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'Edit trip':
        _handleEdit(trip);
      case 'Manage sharing':
        _openShares(trip);
      case 'Save as template':
        showDialog<void>(
          context: context,
          builder: (context) =>
              SaveAsTemplateDialog(tripId: trip.id, tripTitle: trip.title),
        );
      case 'Delete trip':
        await _handleDelete(trip);
    }
  }

  Future<void> _handleDelete(TripModel trip) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete trip',
      body: [
        'This permanently deletes "${trip.title}" and everything in it — '
            'activities, packing list, expenses, documents and memories.',
        'This cannot be undone.',
      ],
      confirmLabel: 'Delete trip',
    );

    if (!confirmed || !mounted) return;

    await ref.read(tripsProvider.notifier).deleteTrip(trip.id);
    if (mounted) context.go(AppRoutes.trips);
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final tripAsync = ref.watch(tripProvider(widget.tripId));

    tripAsync.whenData((trip) {
      if (trip != null && trip != _currentTrip) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentTrip = trip);
        });
      }
    });

    final trip = _currentTrip;

    if (trip == null) {
      return Scaffold(
        backgroundColor: t.canvas,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(onBack: () => context.pop()),
              const SizedBox(height: AppSizes.space24),
              if (tripAsync.hasError)
                OdysseyErrorState(
                  message: 'That trip could not be loaded.',
                  onRetry: () => ref.invalidate(tripProvider(widget.tripId)),
                )
              else
                const Column(
                  children: [
                    Skeleton(width: double.infinity, height: 220,
                        radius: AppSizes.radiusHero),
                    SizedBox(height: AppSizes.space12),
                    Skeleton.row(),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    final detail = Scaffold(
      backgroundColor: t.canvas,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // One sliver, not two: the sheet rides up onto the cover, and a
              // sliver clips to its own bounds, so split across two the
              // overlapping strip was being cut away.
              SliverToBoxAdapter(
                child: OverlapSheet.overlapAbove(
                  cover: _buildCover(trip),
                  sheet: _buildSheet(trip),
                ),
              ),
            ],
          ),
          // Once the cover scrolls away the sheet runs under the status bar,
          // and its headings would collide with the clock. The cover's own
          // scrim covers the same ground while it is still on screen.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                final offset = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;
                // Fades in over the last 80px before the sheet reaches the top.
                final progress =
                    ((offset - (AppSizes.coverHeight - 160)) / 80)
                        .clamp(0.0, 1.0);
                // The status bar icons follow the same fade. Above the fold
                // they sit on the cover photograph, which the scrim keeps
                // dark, so they are light; once the fade has replaced that
                // strip with the canvas they belong to the theme again. A
                // fixed choice is wrong at one end or the other - and it was
                // wrong at the top, where a dark clock sat on a dark cover.
                final overCover = progress < 0.5;
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: (overCover || t.isDark
                          ? SystemUiOverlayStyle.light
                          : SystemUiOverlayStyle.dark)
                      .copyWith(statusBarColor: Colors.transparent),
                  child: Opacity(opacity: progress, child: child!),
                );
              },
              child: StatusBarFade(color: t.canvas),
            ),
          ),
        ],
      ),
    );

    // The coach marks paint over the whole screen, so they sit beside the
    // scaffold rather than wrapping it.
    return Stack(
      children: [
        detail,
        Consumer(
          builder: (context, ref, _) {
            final wt = ref.watch(walkthroughProvider);
            if (!wt.isActive || wt.activeSegmentId != 'trip_detail') {
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

  Widget _buildCover(TripModel trip) {
    final start = TripFormat.parse(trip.startDate);
    final end = TripFormat.parse(trip.endDate);

    return KeyedSubtree(
      key: _heroHeaderKey,
      child: PhotoSurface(
        imageUrl: trip.coverImageUrl,
        seed: trip.id,
        heroTag: 'trip-image-${trip.id}',
        height: AppSizes.coverHeight,
        radius: 0,
        child: Stack(
          children: [
            Positioned(
              left: AppSizes.screenPadding,
              right: AppSizes.screenPadding,
              top: 58,
              child: Row(
                children: [
                  CircleButton(
                    glyph: '←',
                    style: CircleStyle.glass,
                    onPressed: () => context.pop(),
                    semanticLabel: 'Back',
                  ),
                  const Spacer(),
                  CollaborationIndicator(
                    tripId: trip.id,
                    onTap: () => _openShares(trip),
                  ),
                  const SizedBox(width: AppSizes.space8),
                  CircleButton(
                    key: _shareButtonKey,
                    icon: Icons.ios_share_rounded,
                    style: CircleStyle.glass,
                    onPressed: () => _handleShare(trip),
                    semanticLabel: 'Share trip',
                  ),
                  const SizedBox(width: AppSizes.space8),
                  // Lime in both themes — it sits on the photograph, where the
                  // light theme's ink fill would disappear into the scrim.
                  CircleButton(
                    key: _moreOptionsKey,
                    icon: Icons.more_horiz_rounded,
                    style: CircleStyle.brand,
                    onPressed: () => _showOptions(trip),
                    semanticLabel: 'Trip options',
                  ),
                ],
              ),
            ),

            // Sits at 48px so it clears the sheet's 26px overlap.
            Positioned(
              left: AppSizes.screenPadding,
              right: AppSizes.screenPadding,
              bottom: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.title,
                    style: AppTypography.placeName.copyWith(
                      color: AppColors.onPhoto,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.space10),
                  Text(
                    TripFormat.dateRange(start, end),
                    style: AppTypography.meta.copyWith(
                      color: AppColors.onPhoto2,
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

  Widget _buildSheet(TripModel trip) {
    final start = TripFormat.parse(trip.startDate);
    final end = TripFormat.parse(trip.endDate);
    final nights = TripFormat.nights(start, end);

    final activities = ref.watch(tripActivitiesProvider(trip.id));
    final packing = ref.watch(tripPackingProvider(trip.id));
    final readiness = packing.total == 0
        ? null
        : (packing.packedCount / packing.total * 100).round();

    return OverlapSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- stat row ---
          Row(
            children: [
              Expanded(
                child: StatCard(
                  value: '${nights + 1}',
                  label: nights == 0 ? 'day' : 'days',
                ),
              ),
              const SizedBox(width: AppSizes.space10),
              Expanded(
                child: StatCard(
                  value: '${activities.total}',
                  label: activities.total == 1 ? 'plan' : 'plans',
                  loading: activities.isLoading,
                ),
              ),
              const SizedBox(width: AppSizes.space10),
              // The lime tile, in both themes. It shows packing readiness when
              // there is a list to be ready against, and the spend otherwise —
              // an empty list would make "0% ready" the loudest thing on the
              // screen for a trip that simply has no packing list yet.
              Expanded(
                child: StatCard(
                  value: readiness != null ? '$readiness%' : '—',
                  label: readiness != null ? 'ready' : 'no list',
                  highlight: true,
                  // 'no list' is what an empty packing list looks like, and
                  // that is indistinguishable from one that has not loaded
                  // yet. Waiting is not an answer, so say nothing until the
                  // count is real.
                  loading: packing.isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space18),

          KeyedSubtree(
            key: _tabBarKey,
            child: ScrollableSegmentedControl(
              labels: _tabs,
              selected: _tab,
              onSelected: (value) {
                HapticFeedback.selectionClick();
                setState(() => _tab = value);
              },
            ),
          ),
          const SizedBox(height: AppSizes.space18),

          // Panels unmount rather than hide, per the design's note, and enter
          // with a cross-fade and an 8px lift.
          KeyedSubtree(
            key: _tabContentKey,
            child: AnimatedSwitcher(
              duration: AppSizes.durationPanel,
              switchInCurve: AppSizes.curveState,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_tab),
                child: _buildPanel(trip, nights + 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(TripModel trip, int duration) {
    return switch (_tab) {
      'Overview' => TripOverviewTab(trip: trip, duration: duration),
      'Plan' => TripActivitiesTab(tripId: trip.id),
      'Packing' => TripPackingTab(tripId: trip.id),
      'Spend' => TripExpensesTab(tripId: trip.id),
      'Documents' => TripDocumentsTab(tripId: trip.id),
      'Memories' => TripMemoriesTab(tripId: trip.id),
      _ => TripMapTab(tripId: trip.id),
    };
  }
}
