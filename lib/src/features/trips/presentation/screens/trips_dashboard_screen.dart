import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/shimmer_loading.dart';
import '../../../../common/widgets/empty_state.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../core/router/app_router.dart';
import '../providers/trips_provider.dart';
import '../widgets/trip_card.dart';
import 'trip_form_screen.dart';
import 'trip_detail_screen.dart';
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
    
    // Invalidate trips provider to ensure fresh data when dashboard loads
    // This handles the case where provider was built before auth was complete
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
      // Load more when 80% scrolled
      ref.read(tripsProvider.notifier).loadMore();
    }
  }

  Future<void> _handleRefresh() async {
    await ref.read(tripsProvider.notifier).refresh();
  }

  void _handleCreateTrip() {
    context.push(AppRoutes.createTrip).then((_) {
      // Refresh trips when coming back
      ref.read(tripsProvider.notifier).refresh();
    });
  }

  void _handleTripTap(String tripId) {
    // Find the trip in state
    final trip = ref.read(tripsProvider).trips.firstWhere(
          (t) => t.id == tripId,
        );

    // Navigate to detail screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TripDetailScreen(trip: trip),
      ),
    );
  }

  void _handleEditTrip(String tripId) {
    // Find the trip in state
    final trip = ref.read(tripsProvider).trips.firstWhere(
          (t) => t.id == tripId,
        );

    // Navigate to edit screen
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => TripFormScreen(trip: trip),
      ),
    )
        .then((_) {
      // Refresh trips when coming back
      ref.read(tripsProvider.notifier).refresh();
    });
  }

  Future<void> _handleDeleteTrip(String tripId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(tripsProvider.notifier).deleteTrip(tripId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.frostedWhite,
              Colors.white,
            ],
          ),
        ),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Odyssey',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.midnightBlue,
                    ),
                  ),
                  if (authState.user != null)
                    Text(
                      authState.user!.email,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.logout,
                    color: AppColors.midnightBlue,
                  ),
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                  },
                ),
              ],
            ),

            // Refresh wrapper
            SliverToBoxAdapter(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppColors.sunsetGold,
                child: Container(),
              ),
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
                  padding: EdgeInsets.all(AppSizes.space16),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.sunsetGold),
                    ),
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
        icon: Icons.add,
        label: 'New Trip',
        onPressed: _handleCreateTrip,
      ),
    );
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
    return SliverFillRemaining(
      child: NoTripsState(
        onCreateTrip: _handleCreateTrip,
      ),
    );
  }

  Widget _buildTripsList(TripsState state) {
    return SliverPadding(
      padding: const EdgeInsets.only(
        top: AppSizes.space16,
        bottom: AppSizes.space16,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final trip = state.trips[index];
            return TripCard(
              trip: trip,
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
