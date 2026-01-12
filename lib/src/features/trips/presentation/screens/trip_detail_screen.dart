import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/pill_tab_bar.dart';
import '../../../../core/utils/file_url_helper.dart';
import '../../data/models/trip_model.dart';
import '../providers/trips_provider.dart';
import '../widgets/trip_overview_tab.dart';
import '../widgets/trip_activities_tab.dart';
import '../widgets/trip_packing_tab.dart';
import '../widgets/trip_expenses_tab.dart';
import '../widgets/trip_documents_tab.dart';
import '../widgets/trip_memories_tab.dart';
import '../widgets/trip_map_tab.dart';
import 'trip_form_screen.dart';
import '../../../sharing/presentation/widgets/share_trip_dialog.dart';
import '../../../sharing/presentation/widgets/collaboration_indicator.dart';
import '../../../templates/presentation/widgets/save_as_template_dialog.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final String tripId;
  final TripModel? initialTrip;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.initialTrip,
  });

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;
  TripModel? _currentTrip;
  int _selectedTabIndex = 0;

  // Tab items with icons
  static const List<PillTabItem> _tabItems = [
    PillTabItem(label: 'Overview', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
    PillTabItem(label: 'Activities', icon: Icons.event_outlined, activeIcon: Icons.event),
    PillTabItem(label: 'Packing', icon: Icons.luggage_outlined, activeIcon: Icons.luggage),
    PillTabItem(label: 'Budget', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet),
    PillTabItem(label: 'Documents', icon: Icons.folder_outlined, activeIcon: Icons.folder),
    PillTabItem(label: 'Memories', icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library),
    PillTabItem(label: 'Map', icon: Icons.map_outlined, activeIcon: Icons.map),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Use initial trip data immediately for Hero animation
    _currentTrip = widget.initialTrip;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldCollapse = _scrollController.offset > 200;
    if (shouldCollapse != _isCollapsed) {
      setState(() {
        _isCollapsed = shouldCollapse;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the trip provider for fresh data
    final tripAsync = ref.watch(tripProvider(widget.tripId));

    // Update current trip when fresh data arrives
    tripAsync.whenData((trip) {
      if (trip != null && trip != _currentTrip) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _currentTrip = trip;
            });
          }
        });
      }
    });

    // Check loading state for tabs
    final isLoading = tripAsync.isLoading && _currentTrip == null;
    final hasError = tripAsync.hasError && _currentTrip == null;

    // If we have no initial trip and are loading, show loading
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If we have no initial trip and there's an error
    if (hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppSizes.space16),
              Text('Failed to load trip', style: AppTypography.titleMedium),
              const SizedBox(height: AppSizes.space8),
              FilledButton(
                onPressed: () => ref.invalidate(tripProvider(widget.tripId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // If still no trip data (edge case: no initial trip and fetch returned null)
    if (_currentTrip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip')),
        body: const Center(child: Text('Trip not found')),
      );
    }

    // Render with current trip data (Hero animation works immediately)
    return _buildTripDetail(context, _currentTrip!, tripAsync.isLoading);
  }

  Widget _buildTripDetail(BuildContext context, TripModel trip, bool isTabsLoading) {
    final startDate = DateTime.parse(trip.startDate);
    final endDate = DateTime.parse(trip.endDate);
    final duration = endDate.difference(startDate).inDays + 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Scroll to top for smooth Hero animation
        if (_scrollController.offset > 0) {
          await _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.cloudGray,
        body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Hero Image Header
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: AppColors.snowWhite,
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.all(AppSizes.space8),
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    // Scroll to top for smooth Hero animation
                    if (_scrollController.offset > 0) {
                      await _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.snowWhite,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ),
              actions: [
                // Share button
                Padding(
                  padding: const EdgeInsets.only(right: AppSizes.space4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showShareDialog(context, trip);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.space8),
                      decoration: BoxDecoration(
                        color: AppColors.snowWhite,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.share_outlined,
                        color: AppColors.oceanTeal,
                      ),
                    ),
                  ),
                ),
                // Collaborators indicator
                CollaborationIndicator(
                  tripId: trip.id,
                  onTap: () => context.push(
                    '/trips/${trip.id}/shares?title=${Uri.encodeComponent(trip.title)}',
                  ),
                ),
                // More options
                Padding(
                  padding: const EdgeInsets.all(AppSizes.space8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showOptionsMenu(context, trip);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.space8),
                      decoration: BoxDecoration(
                        color: AppColors.snowWhite,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: _isCollapsed
                    ? Text(
                        trip.title,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Image with Hero
                    Hero(
                      tag: 'trip-image-${trip.id}',
                      flightShuttleBuilder: (
                        flightContext,
                        animation,
                        flightDirection,
                        fromHeroContext,
                        toHeroContext,
                      ) {
                        final isPush =
                            flightDirection == HeroFlightDirection.push;
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            // Card has rounded corners, detail has none
                            final t = animation.value;
                            final radius = isPush
                                ? AppSizes.radiusLg * (1 - t)
                                : AppSizes.radiusLg * t;
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(radius),
                              child: Material(
                                color: Colors.transparent,
                                child: _buildCoverImage(trip),
                              ),
                            );
                          },
                        );
                      },
                      child: _buildCoverImage(trip),
                    ),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    // Trip Info on Image
                    if (!_isCollapsed)
                      Positioned(
                        bottom: AppSizes.space16,
                        left: AppSizes.space16,
                        right: AppSizes.space16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.title,
                              style: AppTypography.headlineLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSizes.space8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: AppSizes.iconSm,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: AppSizes.space8),
                                Text(
                                  '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.space16),
                                _buildStatusBadge(trip),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Pill Tab Bar
            SliverPillTabBar(
              tabs: _tabItems,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (index) {
                setState(() => _selectedTabIndex = index);
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ];
        },
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _selectedTabIndex = index);
          },
          children: [
            TripOverviewTab(trip: trip, duration: duration),
            TripActivitiesTab(tripId: trip.id),
            TripPackingTab(tripId: trip.id),
            TripExpensesTab(tripId: trip.id),
            TripDocumentsTab(tripId: trip.id),
            TripMemoriesTab(tripId: trip.id),
            TripMapTab(tripId: trip.id),
          ],
        ),
      ),
      ),
    );
  }

  void _showShareDialog(BuildContext context, TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => ShareTripDialog(
        tripId: trip.id,
        tripTitle: trip.title,
      ),
    );
  }

  void _showSaveAsTemplateDialog(BuildContext context, TripModel trip) {
    showDialog(
      context: context,
      builder: (context) => SaveAsTemplateDialog(
        tripId: trip.id,
        tripTitle: trip.title,
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, TripModel trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.snowWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.charcoal),
              title: const Text('Edit Trip', style: TextStyle(color: AppColors.charcoal)),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TripFormScreen(trip: trip),
                  ),
                ).then((_) {
                  // Refresh trip data after editing
                  ref.invalidate(tripProvider(trip.id));
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline, color: AppColors.oceanTeal),
              title: const Text('Manage Sharing', style: TextStyle(color: AppColors.charcoal)),
              onTap: () {
                Navigator.pop(context);
                context.push('/trips/${trip.id}/shares?title=${Uri.encodeComponent(trip.title)}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_add_outlined, color: AppColors.lavenderDream),
              title: const Text('Save as Template', style: TextStyle(color: AppColors.charcoal)),
              onTap: () {
                Navigator.pop(context);
                _showSaveAsTemplateDialog(context, trip);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete Trip', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Trip'),
                    content: Text('Are you sure you want to delete "${trip.title}"? This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(tripsProvider.notifier).deleteTrip(trip.id);
                  if (context.mounted) {
                    context.go('/');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(TripModel trip) {
    if (trip.coverImageUrl != null &&
        trip.coverImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: FileUrlHelper.getAuthenticatedUrl(trip.coverImageUrl!),
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderCover(),
        errorWidget: (context, url, error) => _buildPlaceholderCover(),
      );
    }
    return _buildPlaceholderCover();
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.softCream,
            AppColors.lemonLight,
            AppColors.sunnyYellow,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 80,
          color: AppColors.sunnyYellow.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TripModel trip) {
    final status = TripStatus.values.firstWhere(
      (s) => s.name == trip.status,
      orElse: () => TripStatus.planned,
    );

    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case TripStatus.planned:
        bgColor = AppColors.statusPlannedBg;
        textColor = AppColors.goldenGlow;
        icon = Icons.schedule_rounded;
        break;
      case TripStatus.ongoing:
        bgColor = AppColors.statusOngoingBg;
        textColor = AppColors.oceanTeal;
        icon = Icons.flight_takeoff_rounded;
        break;
      case TripStatus.completed:
        bgColor = AppColors.statusCompletedBg;
        textColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: AppSizes.space4),
          Text(
            status.displayName,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
