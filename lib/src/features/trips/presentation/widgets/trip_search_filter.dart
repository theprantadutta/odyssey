import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/animations/animation_constants.dart';
import '../../data/models/trip_filter_model.dart';

/// Search bar widget for trips
class TripSearchBar extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onSearch;
  final VoidCallback onFilterTap;
  final int activeFilterCount;

  const TripSearchBar({
    super.key,
    this.initialValue,
    required this.onSearch,
    required this.onFilterTap,
    this.activeFilterCount = 0,
  });

  @override
  State<TripSearchBar> createState() => _TripSearchBarState();
}

class _TripSearchBarState extends State<TripSearchBar>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);

    _animationController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.buttonPress,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onSearch() {
    final query = _controller.text.trim();
    widget.onSearch(query.isEmpty ? null : query);
    _focusNode.unfocus();
    HapticFeedback.lightImpact();
  }

  void _onClear() {
    _controller.clear();
    widget.onSearch(null);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search field
        Expanded(
          child: AnimatedContainer(
            duration: AppAnimations.fast,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: _isFocused ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                width: _isFocused ? 2 : 1,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: AppColors.sunnyYellow.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : AppSizes.softShadow,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: AppTypography.bodyLarge,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _onSearch(),
              decoration: InputDecoration(
                hintText: 'Search trips...',
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: Theme.of(context).hintColor,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _isFocused ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onPressed: _onClear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space16,
                  vertical: AppSizes.space12,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSizes.space8),

        // Filter button
        ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onFilterTap();
            },
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.activeFilterCount > 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: widget.activeFilterCount > 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                boxShadow: AppSizes.softShadow,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: widget.activeFilterCount > 0
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  if (widget.activeFilterCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.coralBurst,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.snowWhite,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            widget.activeFilterCount > 9
                                ? '9+'
                                : widget.activeFilterCount.toString(),
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.snowWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Filter bottom sheet for trips
class TripFilterBottomSheet extends StatefulWidget {
  final TripFilterModel currentFilters;
  final List<String> availableTags;
  final ValueChanged<TripFilterModel> onApply;
  final VoidCallback onClear;

  const TripFilterBottomSheet({
    super.key,
    required this.currentFilters,
    required this.availableTags,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<TripFilterBottomSheet> createState() => _TripFilterBottomSheetState();

  static Future<void> show({
    required BuildContext context,
    required TripFilterModel currentFilters,
    required List<String> availableTags,
    required ValueChanged<TripFilterModel> onApply,
    required VoidCallback onClear,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TripFilterBottomSheet(
        currentFilters: currentFilters,
        availableTags: availableTags,
        onApply: onApply,
        onClear: onClear,
      ),
    );
  }
}

class _TripFilterBottomSheetState extends State<TripFilterBottomSheet> {
  late TripFilterModel _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters;
  }

  void _updateStatus(String status, bool selected) {
    final currentStatuses = _filters.status?.toList() ?? [];
    if (selected) {
      currentStatuses.add(status);
    } else {
      currentStatuses.remove(status);
    }
    setState(() {
      _filters = _filters.copyWith(
        status: currentStatuses.isEmpty ? null : currentStatuses,
        clearStatus: currentStatuses.isEmpty,
      );
    });
    HapticFeedback.selectionClick();
  }

  void _updateTag(String tag, bool selected) {
    final currentTags = _filters.tags?.toList() ?? [];
    if (selected) {
      currentTags.add(tag);
    } else {
      currentTags.remove(tag);
    }
    setState(() {
      _filters = _filters.copyWith(
        tags: currentTags.isEmpty ? null : currentTags,
        clearTags: currentTags.isEmpty,
      );
    });
    HapticFeedback.selectionClick();
  }

  void _updateSorting(TripSortField field) {
    setState(() {
      _filters = _filters.copyWith(sortBy: field);
    });
    HapticFeedback.selectionClick();
  }

  void _updateSortOrder(TripSortOrder order) {
    setState(() {
      _filters = _filters.copyWith(sortOrder: order);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _filters.startDateFrom != null
          ? DateTimeRange(
              start: _filters.startDateFrom!,
              end: _filters.startDateTo ?? _filters.startDateFrom!,
            )
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.sunnyYellow,
                  onPrimary: AppColors.charcoal,
                  surface: AppColors.snowWhite,
                ),
          ),
          child: child!,
        );
      },
    );

    if (result != null) {
      setState(() {
        _filters = _filters.copyWith(
          startDateFrom: result.start,
          startDateTo: result.end,
        );
      });
      HapticFeedback.selectionClick();
    }
  }

  void _clearDateRange() {
    setState(() {
      _filters = _filters.copyWith(
        clearStartDateFrom: true,
        clearStartDateTo: true,
      );
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: AppSizes.space8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(AppSizes.space16),
            child: Row(
              children: [
                Text(
                  'Filter Trips',
                  style: AppTypography.headlineSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                  },
                  child: Text(
                    'Clear All',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.coralBurst,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status filter
                  _buildSectionHeader('Status', Icons.flag_rounded),
                  const SizedBox(height: AppSizes.space8),
                  Wrap(
                    spacing: AppSizes.space8,
                    runSpacing: AppSizes.space8,
                    children: [
                      _buildStatusChip('planned', 'Planned', AppColors.skyBlue),
                      _buildStatusChip(
                          'ongoing', 'Ongoing', AppColors.goldenGlow),
                      _buildStatusChip(
                          'completed', 'Completed', AppColors.oceanTeal),
                    ],
                  ),

                  const SizedBox(height: AppSizes.space24),

                  // Date range filter
                  _buildSectionHeader('Date Range', Icons.calendar_today_rounded),
                  const SizedBox(height: AppSizes.space8),
                  GestureDetector(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.space16),
                      decoration: BoxDecoration(
                        color: AppColors.cloudGray,
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        border: Border.all(color: AppColors.warmGray),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.date_range_rounded,
                            color: _filters.startDateFrom != null
                                ? AppColors.sunnyYellow
                                : AppColors.slate,
                          ),
                          const SizedBox(width: AppSizes.space8),
                          Expanded(
                            child: Text(
                              _filters.startDateFrom != null
                                  ? '${_formatDate(_filters.startDateFrom!)} - ${_formatDate(_filters.startDateTo ?? _filters.startDateFrom!)}'
                                  : 'Select date range',
                              style: AppTypography.bodyMedium.copyWith(
                                color: _filters.startDateFrom != null
                                    ? AppColors.charcoal
                                    : AppColors.mutedGray,
                              ),
                            ),
                          ),
                          if (_filters.startDateFrom != null)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              iconSize: 20,
                              color: AppColors.slate,
                              onPressed: _clearDateRange,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSizes.space24),

                  // Tags filter
                  if (widget.availableTags.isNotEmpty) ...[
                    _buildSectionHeader('Tags', Icons.label_rounded),
                    const SizedBox(height: AppSizes.space8),
                    Wrap(
                      spacing: AppSizes.space8,
                      runSpacing: AppSizes.space8,
                      children: widget.availableTags
                          .map((tag) => _buildTagChip(tag))
                          .toList(),
                    ),
                    const SizedBox(height: AppSizes.space24),
                  ],

                  // Sort by
                  _buildSectionHeader('Sort By', Icons.sort_rounded),
                  const SizedBox(height: AppSizes.space8),
                  Wrap(
                    spacing: AppSizes.space8,
                    runSpacing: AppSizes.space8,
                    children: TripSortField.values.map((field) {
                      final isSelected = _filters.sortBy == field;
                      return FilterChip(
                        label: Text(field.displayName),
                        selected: isSelected,
                        onSelected: (_) => _updateSorting(field),
                        backgroundColor: AppColors.cloudGray,
                        selectedColor: AppColors.lavenderDream.withValues(alpha: 0.3),
                        checkmarkColor: AppColors.lavenderDream,
                        labelStyle: AppTypography.labelMedium.copyWith(
                          color: isSelected
                              ? AppColors.lavenderDream
                              : AppColors.slate,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.lavenderDream
                              : Colors.transparent,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSizes.space16),

                  // Sort order
                  Row(
                    children: [
                      Expanded(
                        child: _buildSortOrderButton(
                          TripSortOrder.desc,
                          'Newest First',
                          Icons.arrow_downward_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSizes.space8),
                      Expanded(
                        child: _buildSortOrderButton(
                          TripSortOrder.asc,
                          'Oldest First',
                          Icons.arrow_upward_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSizes.space32),
                ],
              ),
            ),
          ),

          // Apply button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.space16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_filters);
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sunnyYellow,
                    foregroundColor: AppColors.charcoal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  child: Text(
                    'Apply Filters',
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.slate),
        const SizedBox(width: AppSizes.space4),
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String value, String label, Color color) {
    final isSelected = _filters.status?.contains(value) ?? false;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => _updateStatus(value, selected),
      backgroundColor: AppColors.cloudGray,
      selectedColor: color.withValues(alpha: 0.2),
      checkmarkColor: color,
      avatar: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      labelStyle: AppTypography.labelMedium.copyWith(
        color: isSelected ? color : AppColors.slate,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    final isSelected = _filters.tags?.contains(tag) ?? false;
    return FilterChip(
      label: Text(tag),
      selected: isSelected,
      onSelected: (selected) => _updateTag(tag, selected),
      backgroundColor: AppColors.cloudGray,
      selectedColor: AppColors.oceanTeal.withValues(alpha: 0.2),
      checkmarkColor: AppColors.oceanTeal,
      labelStyle: AppTypography.labelMedium.copyWith(
        color: isSelected ? AppColors.oceanTeal : AppColors.slate,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.oceanTeal : Colors.transparent,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
    );
  }

  Widget _buildSortOrderButton(
    TripSortOrder order,
    String label,
    IconData icon,
  ) {
    final isSelected = _filters.sortOrder == order;
    return GestureDetector(
      onTap: () => _updateSortOrder(order),
      child: AnimatedContainer(
        duration: AppAnimations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.lavenderDream.withValues(alpha: 0.2)
              : AppColors.cloudGray,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(
            color: isSelected ? AppColors.lavenderDream : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.lavenderDream : AppColors.slate,
            ),
            const SizedBox(width: AppSizes.space4),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? AppColors.lavenderDream : AppColors.slate,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Quick filter chips row (for inline filtering)
class TripQuickFilters extends StatelessWidget {
  final TripFilterModel filters;
  final ValueChanged<TripFilterModel> onFilterChanged;

  const TripQuickFilters({
    super.key,
    required this.filters,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
      child: Row(
        children: [
          _QuickFilterChip(
            label: 'All',
            isSelected: !filters.hasActiveFilters,
            onTap: () {
              onFilterChanged(const TripFilterModel());
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(width: AppSizes.space8),
          _QuickFilterChip(
            label: 'Planned',
            icon: Icons.calendar_today_rounded,
            color: AppColors.skyBlue,
            isSelected: filters.status?.contains('planned') ?? false,
            onTap: () {
              final statuses = filters.status?.toList() ?? [];
              if (statuses.contains('planned')) {
                statuses.remove('planned');
              } else {
                statuses.add('planned');
              }
              onFilterChanged(filters.copyWith(
                status: statuses.isEmpty ? null : statuses,
                clearStatus: statuses.isEmpty,
              ));
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(width: AppSizes.space8),
          _QuickFilterChip(
            label: 'Ongoing',
            icon: Icons.flight_takeoff_rounded,
            color: AppColors.goldenGlow,
            isSelected: filters.status?.contains('ongoing') ?? false,
            onTap: () {
              final statuses = filters.status?.toList() ?? [];
              if (statuses.contains('ongoing')) {
                statuses.remove('ongoing');
              } else {
                statuses.add('ongoing');
              }
              onFilterChanged(filters.copyWith(
                status: statuses.isEmpty ? null : statuses,
                clearStatus: statuses.isEmpty,
              ));
              HapticFeedback.selectionClick();
            },
          ),
          const SizedBox(width: AppSizes.space8),
          _QuickFilterChip(
            label: 'Completed',
            icon: Icons.check_circle_rounded,
            color: AppColors.oceanTeal,
            isSelected: filters.status?.contains('completed') ?? false,
            onTap: () {
              final statuses = filters.status?.toList() ?? [];
              if (statuses.contains('completed')) {
                statuses.remove('completed');
              } else {
                statuses.add('completed');
              }
              onFilterChanged(filters.copyWith(
                status: statuses.isEmpty ? null : statuses,
                clearStatus: statuses.isEmpty,
              ));
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.label,
    this.icon,
    this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_QuickFilterChip> createState() => _QuickFilterChipState();
}

class _QuickFilterChipState extends State<_QuickFilterChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppAnimations.micro,
      vsync: this,
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
    final color = widget.color ?? AppColors.sunnyYellow;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space8,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? color.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: widget.isSelected ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected ? null : AppSizes.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSizes.space4),
              ],
              Text(
                widget.label,
                style: AppTypography.labelMedium.copyWith(
                  color: widget.isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
