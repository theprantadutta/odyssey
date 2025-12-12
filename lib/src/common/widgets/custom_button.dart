import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';
import '../animations/animation_constants.dart';

/// Premium custom button with loading state
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final double height;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.height = AppSizes.buttonHeightMd,
    this.borderRadius = AppSizes.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(height),
          side: BorderSide(
            color: backgroundColor ?? AppColors.sunnyYellow,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: _buildContent(),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.sunnyYellow,
        foregroundColor: textColor ?? AppColors.charcoal,
        minimumSize: Size.fromHeight(height),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined ? AppColors.sunnyYellow : AppColors.charcoal,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm),
          const SizedBox(width: AppSizes.space8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}

/// Icon button with soft background
class SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;

  const SoftIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size = AppSizes.iconMd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.softCream,
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.space8),
          child: Icon(
            icon,
            size: size,
            color: iconColor ?? AppColors.sunnyYellow,
          ),
        ),
      ),
    );
  }
}

/// Floating action button with playful design
class GoldFAB extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;

  const GoldFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
  });

  @override
  State<GoldFAB> createState() => _GoldFABState();
}

class _GoldFABState extends State<GoldFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.micro,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.buttonPress,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null) {
      _controller.forward();
      HapticFeedback.mediumImpact();
    }
  }

  void _handleTapUp(TapUpDetails _) => _controller.reverse();
  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.label != null ? AppSizes.space20 : AppSizes.space16,
                vertical: AppSizes.space16,
              ),
              decoration: BoxDecoration(
                color: AppColors.sunnyYellow,
                borderRadius: BorderRadius.circular(
                  widget.label != null ? AppSizes.radiusLg : AppSizes.radiusFull,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sunnyYellow.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: AppColors.charcoal,
                    size: 24,
                  ),
                  if (widget.label != null) ...[
                    const SizedBox(width: AppSizes.space8),
                    Text(
                      widget.label!,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Colorful chip button for tags/filters
class CustomChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isSelected;
  final IconData? icon;
  final Color? color;

  const CustomChip({
    super.key,
    required this.label,
    this.onTap,
    this.onDelete,
    this.isSelected = false,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.oceanTeal;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(
            color: isSelected ? chipColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppSizes.iconXs,
                color: isSelected ? AppColors.charcoal : chipColor,
              ),
              const SizedBox(width: AppSizes.space4),
            ],
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: isSelected ? AppColors.charcoal : chipColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: AppSizes.space4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: AppSizes.iconXs,
                  color: isSelected ? AppColors.charcoal : chipColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status chip with predefined colors
class StatusChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  factory StatusChip.planned() {
    return const StatusChip(
      label: 'Planned',
      backgroundColor: AppColors.statusPlannedBg,
      textColor: AppColors.goldenGlow,
      icon: Icons.schedule_rounded,
    );
  }

  factory StatusChip.ongoing() {
    return const StatusChip(
      label: 'Ongoing',
      backgroundColor: AppColors.statusOngoingBg,
      textColor: AppColors.oceanTeal,
      icon: Icons.flight_takeoff_rounded,
    );
  }

  factory StatusChip.completed() {
    return const StatusChip(
      label: 'Completed',
      backgroundColor: AppColors.statusCompletedBg,
      textColor: AppColors.success,
      icon: Icons.check_circle_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: AppSizes.space4),
          ],
          Text(
            label,
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
