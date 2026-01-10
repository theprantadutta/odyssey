import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Tab item data model
class PillTabItem {
  final String label;
  final IconData icon;
  final IconData? activeIcon;

  const PillTabItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });
}

/// Modern pill-style tab bar with icons
class PillTabBar extends StatelessWidget {
  final List<PillTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedColor;
  final EdgeInsets? padding;

  const PillTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: backgroundColor ?? AppColors.snowWhite,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding ?? const EdgeInsets.symmetric(
          horizontal: AppSizes.space12,
          vertical: AppSizes.space8,
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: AppSizes.space8),
              child: _PillTab(
                item: tabs[index],
                isSelected: isSelected,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTabSelected(index);
                },
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PillTab extends StatefulWidget {
  final PillTabItem item;
  final bool isSelected;
  final Color? selectedColor;
  final Color? unselectedColor;
  final VoidCallback onTap;

  const _PillTab({
    required this.item,
    required this.isSelected,
    this.selectedColor,
    this.unselectedColor,
    required this.onTap,
  });

  @override
  State<_PillTab> createState() => _PillTabState();
}

class _PillTabState extends State<_PillTab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedBgColor = widget.selectedColor ?? AppColors.oceanTeal;
    final unselectedBgColor = widget.unselectedColor ?? AppColors.warmGray;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSelected ? AppSizes.space16 : AppSizes.space12,
            vertical: AppSizes.space8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected ? selectedBgColor : unselectedBgColor,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: selectedBgColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.isSelected
                      ? (widget.item.activeIcon ?? widget.item.icon)
                      : widget.item.icon,
                  key: ValueKey('${widget.item.label}_${widget.isSelected}'),
                  size: 18,
                  color: widget.isSelected
                      ? AppColors.snowWhite
                      : AppColors.slate,
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: widget.isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: AppSizes.space8),
                        child: Text(
                          widget.item.label,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.snowWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sliver adapter for PillTabBar to use in CustomScrollView
class SliverPillTabBar extends StatelessWidget {
  final List<PillTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color? backgroundColor;

  const SliverPillTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverPillTabBarDelegate(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
        backgroundColor: backgroundColor ?? AppColors.snowWhite,
      ),
    );
  }
}

class _SliverPillTabBarDelegate extends SliverPersistentHeaderDelegate {
  final List<PillTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color backgroundColor;

  _SliverPillTabBarDelegate({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.backgroundColor,
  });

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: PillTabBar(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SliverPillTabBarDelegate oldDelegate) {
    return selectedIndex != oldDelegate.selectedIndex ||
        tabs != oldDelegate.tabs;
  }
}
