import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/trip_model.dart';
import '../widgets/trip_overview_tab.dart';
import '../widgets/trip_activities_tab.dart';
import '../widgets/trip_expenses_tab.dart';
import '../widgets/trip_memories_tab.dart';
import '../widgets/trip_map_tab.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  final TripModel trip;

  const TripDetailScreen({
    super.key,
    required this.trip,
  });

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    final startDate = DateTime.parse(widget.trip.startDate);
    final endDate = DateTime.parse(widget.trip.endDate);
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
                Padding(
                  padding: const EdgeInsets.all(AppSizes.space8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      // TODO: Show options menu (edit, delete, share)
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
                        widget.trip.title,
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
                      tag: 'trip-image-${widget.trip.id}',
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
                                child: _buildCoverImage(),
                              ),
                            );
                          },
                        );
                      },
                      child: _buildCoverImage(),
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
                              widget.trip.title,
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
                                _buildStatusBadge(),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.goldenGlow,
                  unselectedLabelColor: AppColors.slate,
                  indicatorColor: AppColors.goldenGlow,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: AppTypography.labelLarge,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Activities'),
                    Tab(text: 'Budget'),
                    Tab(text: 'Memories'),
                    Tab(text: 'Map'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            TripOverviewTab(trip: widget.trip, duration: duration),
            TripActivitiesTab(tripId: widget.trip.id),
            TripExpensesTab(tripId: widget.trip.id),
            TripMemoriesTab(tripId: widget.trip.id),
            TripMapTab(tripId: widget.trip.id),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (widget.trip.coverImageUrl != null &&
        widget.trip.coverImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.trip.coverImageUrl!,
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

  Widget _buildStatusBadge() {
    final status = TripStatus.values.firstWhere(
      (s) => s.name == widget.trip.status,
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

/// Custom delegate for pinned tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.snowWhite,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
