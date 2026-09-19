import 'package:flutter/material.dart';
import '../theme/app_sizes.dart';
import '../theme/odyssey_tokens.dart';
import 'odyssey/chips.dart';

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
    final t = context.odyssey;

    return Container(
      padding: padding ?? const EdgeInsets.all(AppSizes.space18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusTile),
        border: Border.all(color: t.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            // The old header paired a coloured icon chip with a title. This
            // system signals a section with a mono eyebrow instead, so the
            // icon and its tint are dropped rather than recoloured.
            EyebrowLabel(title),
            const SizedBox(height: AppSizes.space14),
          ],
          ...children,
        ],
      ),
    );
  }
}
