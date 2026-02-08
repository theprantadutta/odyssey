import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/animations/animation_constants.dart';
import '../../../../core/utils/file_url_helper.dart';
import '../../data/models/trip_model.dart';

/// Playful trip card with new vibrant design
/// White background, soft shadows, yellow accents
class TripCard extends StatefulWidget {
  final TripModel trip;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int? staggerIndex;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.staggerIndex,
  });

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.cardTap,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: AppSizes.tripCardHeight,
              margin: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.softShadow,
                    blurRadius: _isPressed ? 12 : 24,
                    offset: Offset(0, _isPressed ? 4 : 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Section (60% of card)
                    Expanded(
                      flex: 6,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image with Hero
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
                                      child: _buildImage(),
                                    ),
                                  );
                                },
                              );
                            },
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppSizes.radiusLg),
                              ),
                              child: _buildImage(),
                            ),
                          ),

                          // Subtle gradient overlay at bottom
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.3),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Action Buttons
                          if (widget.onEdit != null || widget.onDelete != null)
                            Positioned(
                              top: AppSizes.space12,
                              right: AppSizes.space12,
                              child: Row(
                                children: [
                                  if (widget.onEdit != null)
                                    _buildActionButton(
                                      icon: Icons.edit_outlined,
                                      onTap: widget.onEdit!,
                                    ),
                                  if (widget.onEdit != null &&
                                      widget.onDelete != null)
                                    const SizedBox(width: AppSizes.space8),
                                  if (widget.onDelete != null)
                                    _buildActionButton(
                                      icon: Icons.delete_outline,
                                      onTap: widget.onDelete!,
                                      isDestructive: true,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Content Section (40% of card)
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.space16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and Status Row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.trip.title,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.space8),
                                _buildStatusBadge(),
                              ],
                            ),

                            const Spacer(),

                            // Date Range
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: AppSizes.iconXs,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppSizes.space8),
                                Text(
                                  _formatDateRange(),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),

                            // Tags
                            if (widget.trip.tags != null &&
                                widget.trip.tags!.isNotEmpty) ...[
                              const SizedBox(height: AppSizes.space8),
                              Wrap(
                                spacing: AppSizes.space8,
                                runSpacing: AppSizes.space4,
                                children: widget.trip.tags!.take(3).map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSizes.space8,
                                      vertical: AppSizes.space4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(
                                          AppSizes.radiusFull),
                                    ),
                                    child: Text(
                                      tag,
                                      style: AppTypography.caption.copyWith(
                                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // Apply stagger animation if index provided
    if (widget.staggerIndex != null) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: AppAnimations.normal,
        curve: AppAnimations.bouncyEnter,
        builder: (context, value, child) {
          return Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }

  Widget _buildImage() {
    if (widget.trip.coverImageUrl != null &&
        widget.trip.coverImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: FileUrlHelper.getAuthenticatedUrl(widget.trip.coverImageUrl!),
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.softCream,
          child: Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.sunnyYellow),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.softCream, AppColors.lemonLight],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.travel_explore,
          size: 56,
          color: AppColors.sunnyYellow.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: AppSizes.iconSm,
          color: isDestructive ? AppColors.error : AppColors.charcoal,
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
    Color iconColor;
    IconData icon;

    switch (status) {
      case TripStatus.planned:
        bgColor = AppColors.statusPlannedBg;
        textColor = AppColors.goldenGlow;
        iconColor = AppColors.sunnyYellow;
        icon = Icons.schedule_rounded;
        break;
      case TripStatus.ongoing:
        bgColor = AppColors.statusOngoingBg;
        textColor = AppColors.oceanTeal;
        iconColor = AppColors.oceanTeal;
        icon = Icons.flight_takeoff_rounded;
        break;
      case TripStatus.completed:
        bgColor = AppColors.statusCompletedBg;
        textColor = AppColors.success;
        iconColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space8,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: iconColor,
          ),
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

  String _formatDateRange() {
    try {
      final startDate = DateTime.parse(widget.trip.startDate);
      final endDate = DateTime.parse(widget.trip.endDate);
      final formatter = DateFormat('MMM d');
      final yearFormatter = DateFormat('yyyy');

      if (startDate.year == endDate.year &&
          startDate.month == endDate.month) {
        return '${formatter.format(startDate)} - ${DateFormat('d').format(endDate)}, ${yearFormatter.format(endDate)}';
      }

      if (startDate.year == endDate.year) {
        return '${formatter.format(startDate)} - ${formatter.format(endDate)}, ${yearFormatter.format(endDate)}';
      }

      return '${formatter.format(startDate)}, ${yearFormatter.format(startDate)} - ${formatter.format(endDate)}, ${yearFormatter.format(endDate)}';
    } catch (e) {
      return '${widget.trip.startDate} - ${widget.trip.endDate}';
    }
  }
}
