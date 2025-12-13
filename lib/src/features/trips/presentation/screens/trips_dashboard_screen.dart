import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/shimmer_loading.dart';
import '../../../../common/widgets/empty_state.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/animations/animation_constants.dart' as anim;
import '../../../../common/animations/loading/bouncing_dots_loader.dart';
import '../../../../core/router/app_router.dart';
import '../providers/trips_provider.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_search_filter.dart';
import 'trip_form_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TripsDashboardScreen extends ConsumerStatefulWidget {
  const TripsDashboardScreen({super.key});

  @override
  ConsumerState<TripsDashboardScreen> createState() =>
      _TripsDashboardScreenState();
}

class _TripsDashboardScreenState extends ConsumerState<TripsDashboardScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(tripsProvider);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  void _handleTripTap(String tripId) {
    HapticFeedback.selectionClick();
    context.push('/trips/$tripId');
  }

  void _handleEditTrip(String tripId) {
    HapticFeedback.lightImpact();
    final trip = ref.read(tripsProvider).trips.firstWhere(
          (t) => t.id == tripId,
        );

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => TripFormScreen(trip: trip),
      ),
    )
        .then((_) {
      ref.read(tripsProvider.notifier).refresh();
    });
  }

  void _handleSearch(String? query) {
    ref.read(tripsProvider.notifier).search(query);
  }

  void _openFilterSheet() {
    final state = ref.read(tripsProvider);
    TripFilterBottomSheet.show(
      context: context,
      currentFilters: state.filters,
      availableTags: state.availableTags,
      onApply: (filters) {
        ref.read(tripsProvider.notifier).updateFilters(filters);
      },
      onClear: () {
        ref.read(tripsProvider.notifier).clearFilters();
      },
    );
  }

  Future<void> _handleDeleteTrip(String tripId, String title) async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.snowWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Delete Trip',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.slate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.slate,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.coralBurst,
            ),
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.coralBurst,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(tripsProvider.notifier).deleteTrip(tripId);
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: AppSizes.space12),
                  const Text('Trip deleted successfully'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsState = ref.watch(tripsProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.cloudGray,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppColors.sunnyYellow,
        backgroundColor: AppColors.snowWhite,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.cloudGray,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 80,
              title: _buildHeader(authState),
              actions: [
                // Templates button
                Container(
                  margin: const EdgeInsets.only(right: AppSizes.space8),
                  decoration: BoxDecoration(
                    color: AppColors.snowWhite,
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
                    icon: const Icon(
                      Icons.bookmarks_outlined,
                      color: AppColors.lavenderDream,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.templates);
                    },
                    tooltip: 'Templates',
                  ),
                ),
                // Shared trips button
                Container(
                  margin: const EdgeInsets.only(right: AppSizes.space8),
                  decoration: BoxDecoration(
                    color: AppColors.snowWhite,
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
                    icon: const Icon(
                      Icons.people_outline_rounded,
                      color: AppColors.oceanTeal,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.sharedTrips);
                    },
                    tooltip: 'Shared trips',
                  ),
                ),
                // Achievements button
                Container(
                  margin: const EdgeInsets.only(right: AppSizes.space8),
                  decoration: BoxDecoration(
                    color: AppColors.snowWhite,
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
                    icon: const Icon(
                      Icons.emoji_events_outlined,
                      color: AppColors.sunnyYellow,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push(AppRoutes.achievements);
                    },
                    tooltip: 'Achievements',
                  ),
                ),
                // Logout button
                Container(
                  margin: const EdgeInsets.only(right: AppSizes.space16),
                  decoration: BoxDecoration(
                    color: AppColors.snowWhite,
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
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.slate,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(authProvider.notifier).logout();
                    },
                    tooltip: 'Logout',
                  ),
                ),
              ],
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.space16,
                  AppSizes.space8,
                  AppSizes.space16,
                  AppSizes.space8,
                ),
                child: TripSearchBar(
                  initialValue: tripsState.filters.search,
                  onSearch: _handleSearch,
                  onFilterTap: _openFilterSheet,
                  activeFilterCount: tripsState.filters.activeFilterCount,
                ),
              ),
            ),

            // Quick Filters
            SliverToBoxAdapter(
              child: TripQuickFilters(
                filters: tripsState.filters,
                onFilterChanged: (filters) {
                  ref.read(tripsProvider.notifier).updateFilters(filters);
                },
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: AppSizes.space8),
            ),

            // Content
            if (tripsState.isLoading && tripsState.trips.isEmpty)
              _buildLoadingState()
            else if (tripsState.error != null && tripsState.trips.isEmpty)
              _buildErrorState(tripsState.error!)
            else if (tripsState.trips.isEmpty)
              _buildEmptyState()
            else
              _buildTripsList(tripsState),

            // Loading indicator for pagination
            if (tripsState.isLoading && tripsState.trips.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.space24),
                  child: Center(
                    child: BouncingDotsLoader(),
                  ),
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSizes.space80),
            ),
          ],
        ),
      ),
      floatingActionButton: GoldFAB(
        icon: Icons.add_rounded,
        label: 'New Trip',
        onPressed: _handleCreateTrip,
      ),
    );
  }

  Widget _buildHeader(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getGreeting(),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.slate,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: const Icon(
                Icons.travel_explore,
                color: AppColors.goldenGlow,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Text(
              'Odyssey',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildLoadingState() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const TripCardSkeleton(),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return SliverFillRemaining(
      child: ErrorState(
        message: error,
        onRetry: _handleRefresh,
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters = ref.read(tripsProvider).filters.hasActiveFilters;

    if (hasFilters) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.space32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: anim.AppAnimations.medium,
                  curve: anim.AppAnimations.bounce,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.space24),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderDream.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: AppColors.lavenderDream,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.space24),
                Text(
                  'No trips found',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                Text(
                  'Try adjusting your search or filters',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.slate,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.space24),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(tripsProvider.notifier).clearFilters();
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Clear filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.lavenderDream,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverFillRemaining(
      child: NoTripsState(
        onCreateTrip: _handleCreateTrip,
      ),
    );
  }

  Widget _buildTripsList(TripsState state) {
    return SliverPadding(
      padding: const EdgeInsets.only(
        top: AppSizes.space8,
        bottom: AppSizes.space16,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final trip = state.trips[index];
            return TripCard(
              trip: trip,
              staggerIndex: index,
              onTap: () => _handleTripTap(trip.id),
              onEdit: () => _handleEditTrip(trip.id),
              onDelete: () => _handleDeleteTrip(trip.id, trip.title),
            );
          },
          childCount: state.trips.length,
        ),
      ),
    );
  }
}
