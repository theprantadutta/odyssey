import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

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
        backgroundColor: backgroundColor ?? AppColors.sunsetGold,
        foregroundColor: textColor ?? AppColors.midnightBlue,
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
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

/// Icon button with glass effect
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double size;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.size = AppSizes.iconMd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.space8),
          child: Icon(
            icon,
            size: size,
            color: iconColor ?? AppColors.textOnDark,
          ),
        ),
      ),
    );
  }
}

/// Floating action button with gold gradient
class GoldFAB extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (label != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label!,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.midnightBlue,
          ),
        ),
        backgroundColor: AppColors.sunsetGold,
        foregroundColor: AppColors.midnightBlue,
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.sunsetGold,
      foregroundColor: AppColors.midnightBlue,
      child: Icon(icon),
    );
  }
}

/// Chip button for tags/filters
class CustomChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isSelected;
  final IconData? icon;

  const CustomChip({
    super.key,
    required this.label,
    this.onTap,
    this.onDelete,
    this.isSelected = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sunsetGold : AppColors.paleGold,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconXs, color: AppColors.midnightBlue),
              const SizedBox(width: AppSizes.space4),
            ],
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.midnightBlue,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: AppSizes.space4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: AppSizes.iconXs,
                  color: AppColors.midnightBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
