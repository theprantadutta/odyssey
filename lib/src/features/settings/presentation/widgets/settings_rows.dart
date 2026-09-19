import 'package:flutter/material.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';

/// A row inside a [GroupedCard] that ends in a switch.
///
/// Icon chip, label, optional meta line, then the 46×28 track.
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.meta,
    this.circleChip = false,
  });

  final IconData icon;
  final String label;
  final String? meta;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool circleChip;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space16,
        vertical: AppSizes.space14,
      ),
      child: Row(
        children: [
          IconChip(icon: icon, circle: circleChip),
          const SizedBox(width: AppSizes.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.rowLabel.copyWith(color: t.ink),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta!,
                    style: AppTypography.badgeDesc.copyWith(color: t.ink3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.space12),
          OdysseySwitch(
            value: value,
            onChanged: onChanged,
            semanticLabel: label,
          ),
        ],
      ),
    );
  }
}

/// A row inside a [GroupedCard] that navigates: icon chip, label, a
/// right-aligned value, and a chevron.
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.meta,
    this.onTap,
    this.circleChip = false,
    this.trailing,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;

  /// Right-aligned current value — `BDT ৳`, `Metric`, `Pro · yearly`.
  final String? value;

  /// A second line under the label, for rows that need explaining.
  final String? meta;

  final VoidCallback? onTap;

  /// The design alternates rounded-square and circular chips down the list.
  final bool circleChip;

  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space14,
        ),
        child: Row(
          children: [
            IconChip(icon: icon, circle: circleChip),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.rowLabel.copyWith(
                      color: onTap == null ? t.ink2 : t.ink,
                    ),
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta!,
                      style: AppTypography.badgeDesc.copyWith(color: t.ink3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: AppSizes.space10),
              Flexible(
                child: Text(
                  value!,
                  style: AppTypography.caption.copyWith(color: t.ink3),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: AppSizes.space10),
              trailing!,
            ] else if (showChevron && onTap != null) ...[
              const SizedBox(width: AppSizes.space8),
              Text(
                '›',
                style: AppTypography.glyph.copyWith(
                  fontSize: 15,
                  color: t.ink3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
