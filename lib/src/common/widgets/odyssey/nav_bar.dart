import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'pressable.dart';
import 'surfaces.dart';

/// One destination in the floating nav.
class NavDestination {
  const NavDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The floating glass nav: four equal pills inside a blurred, hairlined bar.
///
/// The design draws the marks as alternating circles and rounded squares
/// rather than as icons. That alternation is intentional — it is the one place
/// the system's primitive-shape iconography survives into production — so this
/// keeps the shapes and treats [NavDestination.icon] as the accessible label's
/// backing only.
///
/// Active pill: lime with obsidian mark and label in dark; obsidian with a
/// *lime* mark and paper label in light.
class OdysseyNavBar extends StatelessWidget {
  const OdysseyNavBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        0,
        AppSizes.screenPadding,
        // The design's 28px sits above the home indicator; on a device without
        // one, 28px from the physical edge is right.
        bottomInset > 0 ? AppSizes.space10 : AppSizes.navBottomInset,
      ),
      child: GlassBar(
        padding: const EdgeInsets.all(7),
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSizes.space4),
              Expanded(
                child: _NavItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  // Marks alternate rounded-square, circle, rounded-square…
                  circleMark: i.isOdd,
                  onTap: () => onSelected(i),
                  tokens: t,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.circleMark,
    required this.onTap,
    required this.tokens,
  });

  final NavDestination destination;
  final bool selected;
  final bool circleMark;
  final VoidCallback onTap;
  final OdysseyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;

    final Color bg = selected ? t.action : Colors.transparent;
    final Color markColor = selected
        ? t.actionGlyph
        : (t.isDark ? const Color(0x73FFFFFF) : const Color(0x4D0A0B0D));
    final Color labelColor = selected
        ? t.onAction
        : (t.isDark ? const Color(0x80FFFFFF) : const Color(0x4D0A0B0D));

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      tint: false,
      selected: selected,
      semanticLabel: destination.label,
      child: AnimatedContainer(
        duration: AppSizes.durationState,
        curve: AppSizes.curveState,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: AppSizes.durationState,
              curve: AppSizes.curveState,
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: markColor,
                shape: circleMark ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circleMark ? null : BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                destination.label,
                style: AppTypography.navLabel.copyWith(color: labelColor),
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four destinations of the app shell.
const List<NavDestination> kOdysseyDestinations = [
  NavDestination(label: 'Home', icon: Icons.home_outlined),
  NavDestination(label: 'Trips', icon: Icons.luggage_outlined),
  NavDestination(label: 'Map', icon: Icons.map_outlined),
  NavDestination(label: 'You', icon: Icons.person_outline),
];

/// The vertical space a scrolling screen must reserve so its last row clears
/// the floating nav.
///
/// Add this as the final sliver or the bottom padding of any scroll view on a
/// nav-bearing screen.
double navScrollSpacer(BuildContext context) {
  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  return AppSizes.navSpacer + bottomInset;
}

/// How tall the floating nav actually is, including its own bottom padding.
///
/// Use this to pin something above the nav — a map's selected-pin card, a
/// paywall on a tab root — rather than guessing at a constant.
double navBarHeight(BuildContext context) {
  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
  // 7px bar padding + 12px item padding, top and bottom, around a 13px mark.
  const bar = 7 + 12 + 13 + 12 + 7;
  final outer = bottomInset > 0
      ? AppSizes.space10 + bottomInset
      : AppSizes.navBottomInset;
  return bar + outer;
}
