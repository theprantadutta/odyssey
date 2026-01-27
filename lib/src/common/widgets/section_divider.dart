import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// A subtle horizontal divider with optional centered label
///
/// Used to visually separate sections in forms and detail screens.
/// Provides consistent spacing and styling across the app.
class SectionDivider extends StatelessWidget {
  /// Optional text label displayed in the center of the divider
  final String? label;

  /// Padding around the divider
  /// Defaults to symmetric vertical padding of [AppSizes.space16]
  final EdgeInsets padding;

  /// The thickness of the divider line
  /// Defaults to 1.0
  final double thickness;

  /// The color of the divider line
  /// Defaults to [AppColors.mutedGray] with 0.3 opacity
  final Color? color;

  const SectionDivider({
    super.key,
    this.label,
    this.padding = const EdgeInsets.symmetric(vertical: AppSizes.space16),
    this.thickness = 1.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = color ?? AppColors.mutedGray.withValues(alpha: 0.3);

    if (label == null) {
      return Padding(
        padding: padding,
        child: Divider(
          height: thickness,
          thickness: thickness,
          color: dividerColor,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: thickness,
              thickness: thickness,
              color: dividerColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
            child: Text(
              label!,
              style: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: thickness,
              thickness: thickness,
              color: dividerColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A larger section header divider with a more prominent style
///
/// Used for major section breaks with descriptive labels
class SectionHeader extends StatelessWidget {
  /// The section title
  final String title;

  /// Optional subtitle or description
  final String? subtitle;

  /// Padding around the header
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.only(
      top: AppSizes.space24,
      bottom: AppSizes.space12,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSizes.space4),
            Text(
              subtitle!,
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
