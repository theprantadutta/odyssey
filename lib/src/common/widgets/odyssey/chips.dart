import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'pressable.dart';

/// A mono, uppercase, widely tracked eyebrow label.
///
/// `NEXT TRIP` · `ODYSSEY POINTS` · `REMAINING` · `SPENT OF ¥182,000`
///
/// Uppercases its own copy, so pass it in whatever case reads best in source.
/// Defaults to [OdysseyTokens.ink3]; on a lime surface pass
/// [AppColors.onAccentLabel].
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(
    this.label, {
    super.key,
    this.color,
    this.tight = false,
  });

  final String label;
  final Color? color;

  /// The slightly smaller, tighter cut used inside dense cards.
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Text(
      label.toUpperCase(),
      style: (tight ? AppTypography.eyebrowTight : AppTypography.eyebrow)
          .copyWith(color: color ?? t.ink3),
    );
  }
}

/// How a selected [OdysseyChip] fills.
enum ChipActiveStyle {
  /// Paper-on-obsidian in dark, obsidian-on-paper in light. The home filter
  /// chips and the segmented controls use this.
  invert,

  /// The theme's primary action colour — lime in dark, ink in light. Trip
  /// style, packing groups, budget categories and document filters use this.
  action,
}

/// A filter chip: fully rounded, Manrope 12.5/600, idle as a hairlined card
/// and selected as a solid fill.
class OdysseyChip extends StatelessWidget {
  const OdysseyChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.activeStyle = ChipActiveStyle.invert,
    this.padding = const EdgeInsets.symmetric(
      horizontal: 15,
      vertical: 9,
    ),
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final ChipActiveStyle activeStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final Color bg;
    final Color fg;
    if (!selected) {
      bg = t.card;
      fg = t.ink2;
    } else if (activeStyle == ChipActiveStyle.invert) {
      bg = t.invert;
      fg = t.onInvert;
    } else {
      bg = t.action;
      fg = t.onAction;
    }

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      tint: !selected,
      selected: selected,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppSizes.durationState,
        curve: AppSizes.curveState,
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(
            color: selected ? Colors.transparent : t.hairline,
          ),
        ),
        child: Text(label, style: AppTypography.chip.copyWith(color: fg)),
      ),
    );
  }
}

/// A horizontally scrolling row of single-select chips.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.activeStyle = ChipActiveStyle.invert,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSizes.screenPadding,
    ),
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;
  final ChipActiveStyle activeStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSizes.space8),
            OdysseyChip(
              label: labels[i],
              selected: labels[i] == selected,
              activeStyle: activeStyle,
              onTap: () => onSelected(labels[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// A wrapping set of single-select chips — the trip-style picker.
class ChipWrap extends StatelessWidget {
  const ChipWrap({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.activeStyle = ChipActiveStyle.action,
  });

  final List<String> labels;
  final String? selected;
  final ValueChanged<String> onSelected;
  final ChipActiveStyle activeStyle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.space8,
      runSpacing: AppSizes.space8,
      children: [
        for (final label in labels)
          OdysseyChip(
            label: label,
            selected: label == selected,
            activeStyle: activeStyle,
            onTap: () => onSelected(label),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          ),
      ],
    );
  }
}

/// A segmented control: a [OdysseyTokens.track] rail holding equal-width tabs,
/// the selected one filled.
///
/// Plan / Stays / Spend · Light / Dark / System · 2026 / All time.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.expand = true,
    this.tabPadding = const EdgeInsets.symmetric(vertical: 11),
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  /// Whether tabs share the width equally. Turn off for the compact range
  /// control on the statistics header, which hugs its labels.
  final bool expand;

  final EdgeInsetsGeometry tabPadding;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    Widget tab(String label) {
      final on = label == selected;
      final child = Pressable(
        onTap: () => onSelected(label),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        tint: false,
        selected: on,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: AppSizes.durationState,
          curve: AppSizes.curveState,
          padding: expand
              ? tabPadding
              : const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? t.invert : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Text(
            label,
            style: (on ? AppTypography.tab : AppTypography.chip).copyWith(
              color: on ? t.onInvert : t.ink2,
            ),
          ),
        ),
      );
      return expand ? Expanded(child: child) : child;
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.space4),
      decoration: BoxDecoration(
        color: t.track,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: t.hairline),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSizes.space4),
            tab(labels[i]),
          ],
        ],
      ),
    );
  }
}

/// A small lime badge — `DAY 3 / 6`, `CONFIRMED`, `CHECKED IN`, `PRO`.
///
/// Lime in both themes: these sit on photography or on a card where the brand
/// colour is the point.
class OdysseyBadge extends StatelessWidget {
  const OdysseyBadge(
    this.label, {
    super.key,
    this.color = AppColors.accent,
    this.textColor = AppColors.onAccent,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(color: textColor),
      ),
    );
  }
}

/// The mono tag that ends a list row — `DOCS` / `TECH` / `WEAR` / `CARE`.
class MonoTag extends StatelessWidget {
  const MonoTag(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Text(
      label.toUpperCase(),
      style: AppTypography.monoTag.copyWith(color: color ?? t.ink3),
    );
  }
}

/// A rounded pill carrying a status dot and a label — the home screen's
/// location chip.
class DotPill extends StatelessWidget {
  const DotPill({
    super.key,
    required this.label,
    this.onTap,
    this.dotColor,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 13, 8),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(color: t.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                // Lime reads as "live" in dark; on paper it disappears, so the
                // light theme uses ink for the same signal.
                color: dotColor ?? (t.isDark ? AppColors.accent : t.ink),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(label, style: AppTypography.pill.copyWith(color: t.ink2)),
          ],
        ),
      ),
    );
  }
}
