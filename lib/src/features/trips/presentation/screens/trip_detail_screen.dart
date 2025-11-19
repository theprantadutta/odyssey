import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/trip_model.dart';
import '../widgets/trip_overview_tab.dart';
import '../widgets/trip_activities_tab.dart';
import '../widgets/trip_memories_tab.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Collapse header when scrolled past threshold
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

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Hero Image Header
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: AppColors.midnightBlue,
              leading: Container(
                margin: const EdgeInsets.all(AppSizes.space8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.all(AppSizes.space8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      // TODO: Show options menu (edit, delete, share)
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: _isCollapsed
                    ? Text(
                        widget.trip.title,
                        style: AppTypography.headlineSmall.copyWith(
                          color: Colors.white,
                          shadows: [
                            const Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      )
                    : null,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Image
                    if (widget.trip.coverImageUrl != null)
                      Image.network(
                        widget.trip.coverImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildDefaultCover();
                        },
                      )
                    else
                      _buildDefaultCover(),
                    // Gradient Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
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
                                shadows: [
                                  const Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSizes.space8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.space12,
                                    vertical: AppSizes.space4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(widget.trip.status)
                                        .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.radiusFull,
                                    ),
                                  ),
                                  child: Text(
                                    TripStatus.values
                                        .firstWhere(
                                          (s) => s.name == widget.trip.status,
                                          orElse: () => TripStatus.planned,
                                        )
                                        .displayName,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.midnightBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
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
                  labelColor: AppColors.sunsetGold,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.sunsetGold,
                  labelStyle: AppTypography.labelLarge,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Activities'),
                    Tab(text: 'Memories'),
                  ],
                ),
              ),
            ),
          ];
        },
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
          child: TabBarView(
            controller: _tabController,
            children: [
              TripOverviewTab(trip: widget.trip, duration: duration),
              TripActivitiesTab(tripId: widget.trip.id),
              TripMemoriesTab(tripId: widget.trip.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepNavy,
            AppColors.midnightBlue,
            AppColors.sunsetGold.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape,
          size: 80,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'planned':
        return AppColors.paleGold;
      case 'ongoing':
        return AppColors.sunsetGold;
      case 'completed':
        return AppColors.mintGreen;
      default:
        return AppColors.paleGold;
    }
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
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
