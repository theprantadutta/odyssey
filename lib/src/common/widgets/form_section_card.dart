import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Reusable card component for form sections
///
/// Provides consistent styling across all form screens with:
/// - White background with soft shadow
/// - Icon header with title
/// - Consistent padding and border radius
class FormSectionCard extends StatelessWidget {
  /// Section title displayed next to the icon
  final String title;

  /// Icon displayed in the header
  final IconData icon;

  /// Content widgets inside the card
  final List<Widget> children;

  /// Background color for the icon container
  /// Defaults to [AppColors.lemonLight]
  final Color? iconBackgroundColor;

  /// Color of the icon
  /// Defaults to [AppColors.sunnyYellow]
  final Color? iconColor;

  /// Whether to show the header section
  /// Set to false for cards that only need the card styling
  final bool showHeader;

  /// Custom padding for the card content
  /// Defaults to [AppSizes.space20] on all sides
  final EdgeInsets? padding;

  const FormSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.iconBackgroundColor,
    this.iconColor,
    this.showHeader = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding ?? const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            _buildHeader(context),
            const SizedBox(height: AppSizes.space16),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBackgroundColor ?? AppColors.lemonLight,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppColors.sunnyYellow,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSizes.space12),
        Expanded(
          child: Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
