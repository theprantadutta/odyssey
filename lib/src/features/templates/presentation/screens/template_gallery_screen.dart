import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/template_model.dart';
import '../providers/templates_provider.dart';
import '../widgets/template_card.dart';
import '../widgets/use_template_dialog.dart';

class TemplateGalleryScreen extends ConsumerStatefulWidget {
  const TemplateGalleryScreen({super.key});

  @override
  ConsumerState<TemplateGalleryScreen> createState() =>
      _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends ConsumerState<TemplateGalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _buildBackButton(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Templates',
              style: AppTypography.headlineSmall.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Discover and save travel plans',
              style: AppTypography.bodySmall.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.goldenGlow,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              indicatorColor: AppColors.goldenGlow,
              indicatorWeight: 3,
              labelStyle: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Discover'),
                Tab(text: 'My Templates'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PublicTemplatesTab(searchController: _searchController),
          const _MyTemplatesTab(),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSizes.space8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _PublicTemplatesTab extends ConsumerStatefulWidget {
  final TextEditingController searchController;

  const _PublicTemplatesTab({required this.searchController});

  @override
  ConsumerState<_PublicTemplatesTab> createState() =>
      _PublicTemplatesTabState();
}

class _PublicTemplatesTabState extends ConsumerState<_PublicTemplatesTab> {
  TemplateCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final galleryState = ref.watch(templateGalleryProvider);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(AppSizes.space16),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: widget.searchController,
              style: AppTypography.bodyLarge.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search templates...',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: theme.hintColor,
                ),
                prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                suffixIcon: widget.searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          widget.searchController.clear();
                          ref.read(templateGalleryProvider.notifier).search(null);
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: const BorderSide(
                    color: AppColors.sunnyYellow,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space16,
                  vertical: AppSizes.space12,
                ),
              ),
              onChanged: (value) => setState(() {}),
              onSubmitted: (value) {
                ref.read(templateGalleryProvider.notifier).search(value);
              },
            ),
          ),
        ),

        // Category filter
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
            children: [
              _CategoryChip(
                label: 'All',
                isSelected: _selectedCategory == null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = null);
                  ref.read(templateGalleryProvider.notifier).filterByCategory(null);
                },
              ),
              const SizedBox(width: AppSizes.space8),
              ...TemplateCategory.values.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSizes.space8),
                  child: _CategoryChip(
                    label: '${category.icon} ${category.displayName}',
                    isSelected: _selectedCategory == category,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = category);
                      ref.read(templateGalleryProvider.notifier).filterByCategory(category);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: AppSizes.space16),

        // Templates list
        Expanded(
          child: galleryState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.sunnyYellow,
                  ),
                )
              : galleryState.error != null
                  ? _ErrorWidget(
                      message: galleryState.error!,
                      onRetry: () =>
                          ref.read(templateGalleryProvider.notifier).refresh(),
                    )
                  : galleryState.templates.isEmpty
                      ? _EmptyStateWidget(
                          icon: Icons.explore_outlined,
                          title: 'No templates found',
                          subtitle: _selectedCategory != null ||
                                  widget.searchController.text.isNotEmpty
                              ? 'Try adjusting your filters'
                              : 'Be the first to share a template!',
                        )
                      : RefreshIndicator(
                          color: AppColors.sunnyYellow,
                          backgroundColor: colorScheme.surface,
                          onRefresh: () => ref
                              .read(templateGalleryProvider.notifier)
                              .refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.space16,
                            ),
                            itemCount: galleryState.templates.length,
                            itemBuilder: (context, index) {
                              final template = galleryState.templates[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSizes.space16),
                                child: TemplateCard(
                                  template: template,
                                  onTap: () =>
                                      _showTemplateDetails(context, template),
                                  onUse: () =>
                                      _useTemplate(context, ref, template),
                                  onFork: () =>
                                      _forkTemplate(context, ref, template),
                                  showActions: true,
                                  showForkButton: true,
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  void _showTemplateDetails(BuildContext context, TripTemplateModel template) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      builder: (context) => _TemplateDetailsSheet(template: template),
    );
  }

  Future<void> _useTemplate(
    BuildContext context,
    WidgetRef ref,
    TripTemplateModel template,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => UseTemplateDialog(template: template),
    );

    if (result != null && context.mounted) {
      final tripId = result['id'] as String?;
      if (tripId != null) {
        context.push('/trips/$tripId');
      }
    }
  }

  Future<void> _forkTemplate(
    BuildContext context,
    WidgetRef ref,
    TripTemplateModel template,
  ) async {
    final colorScheme = Theme.of(context).colorScheme;
    HapticFeedback.lightImpact();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Save to My Templates',
          style: AppTypography.headlineSmall.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This will create a copy of "${template.name}" in your templates. You can customize it later.',
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.oceanTeal,
            ),
            child: Text(
              'Save',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.oceanTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final forked =
          await ref.read(myTemplatesProvider.notifier).forkTemplate(template.id);
      if (forked != null && context.mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Expanded(child: Text('Saved "${forked.name}" to your templates')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      } else if (context.mounted) {
        final myTemplatesState = ref.read(myTemplatesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Text(
                    myTemplatesState.error ?? 'Failed to save template',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sunnyYellow : colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.sunnyYellow.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MyTemplatesTab extends ConsumerWidget {
  const _MyTemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final myTemplatesState = ref.watch(myTemplatesProvider);

    if (myTemplatesState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.sunnyYellow),
      );
    }

    if (myTemplatesState.error != null) {
      return _ErrorWidget(
        message: myTemplatesState.error!,
        onRetry: () => ref.read(myTemplatesProvider.notifier).refresh(),
      );
    }

    if (myTemplatesState.templates.isEmpty) {
      return const _EmptyStateWidget(
        icon: Icons.bookmark_add_outlined,
        title: 'No templates yet',
        subtitle: 'Save a trip as a template to reuse it later',
      );
    }

    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      backgroundColor: colorScheme.surface,
      onRefresh: () => ref.read(myTemplatesProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSizes.space16),
        itemCount: myTemplatesState.templates.length,
        itemBuilder: (context, index) {
          final template = myTemplatesState.templates[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.space16),
            child: TemplateCard(
              template: template,
              onTap: () => _showTemplateDetails(context, template),
              onUse: () => _useTemplate(context, ref, template),
              onDelete: () => _deleteTemplate(context, ref, template),
              showActions: true,
            ),
          );
        },
      ),
    );
  }

  void _showTemplateDetails(BuildContext context, TripTemplateModel template) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      builder: (context) => _TemplateDetailsSheet(template: template),
    );
  }

  Future<void> _useTemplate(
    BuildContext context,
    WidgetRef ref,
    TripTemplateModel template,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => UseTemplateDialog(template: template),
    );

    if (result != null && context.mounted) {
      final tripId = result['id'] as String?;
      if (tripId != null) {
        context.push('/trips/$tripId');
      }
    }
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    TripTemplateModel template,
  ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Delete Template',
          style: AppTypography.headlineSmall.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${template.name}"?',
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(myTemplatesProvider.notifier).deleteTemplate(template.id);
      if (success && context.mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Text('Template "${template.name}" deleted'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    }
  }
}

class _TemplateDetailsSheet extends StatelessWidget {
  final TripTemplateModel template;

  const _TemplateDetailsSheet({required this.template});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final structure = template.structure;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.hintColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space24),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.space16),
                    decoration: BoxDecoration(
                      color: AppColors.lemonLight,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Text(
                      template.category?.icon ?? '',
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: AppTypography.headlineSmall.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (template.category != null)
                          Text(
                            template.category!.displayName,
                            style: AppTypography.bodyMedium.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              if (template.description != null) ...[
                const SizedBox(height: AppSizes.space16),
                Text(
                  template.description!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.space24),
              Container(
                height: 1,
                color: colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: AppSizes.space24),

              // Stats
              Text(
                'Template Contents',
                style: AppTypography.titleMedium.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.space16),

              Wrap(
                spacing: AppSizes.space12,
                runSpacing: AppSizes.space12,
                children: [
                  if (structure.durationDays != null)
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: '${structure.durationDays} days',
                      color: AppColors.oceanTeal,
                    ),
                  if (structure.activities.isNotEmpty)
                    _InfoChip(
                      icon: Icons.checklist_outlined,
                      label: '${structure.activities.length} activities',
                      color: AppColors.coralBurst,
                    ),
                  if (structure.packingItems.isNotEmpty)
                    _InfoChip(
                      icon: Icons.luggage_outlined,
                      label: '${structure.packingItems.length} packing items',
                      color: AppColors.lavenderDream,
                    ),
                  _InfoChip(
                    icon: Icons.trending_up_outlined,
                    label: '${template.useCount} uses',
                    color: AppColors.sunnyYellow,
                  ),
                ],
              ),

              // Activities list
              if (structure.activities.isNotEmpty) ...[
                const SizedBox(height: AppSizes.space24),
                Text(
                  'Included Activities',
                  style: AppTypography.titleSmall.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                ...structure.activities.take(5).map((activity) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.space8),
                    padding: const EdgeInsets.all(AppSizes.space12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getCategoryIcon(activity.category),
                            size: 20,
                            color: AppColors.oceanTeal,
                          ),
                        ),
                        const SizedBox(width: AppSizes.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (activity.location != null)
                                Text(
                                  activity.location!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (structure.activities.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.space8),
                    child: Text(
                      '+${structure.activities.length - 5} more activities',
                      style: AppTypography.bodySmall.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],

              // Tips
              if (structure.tips.isNotEmpty) ...[
                const SizedBox(height: AppSizes.space24),
                Text(
                  'Tips',
                  style: AppTypography.titleSmall.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                ...structure.tips.map((tip) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.space8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.lemonLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: AppColors.goldenGlow,
                          ),
                        ),
                        const SizedBox(width: AppSizes.space12),
                        Expanded(
                          child: Text(
                            tip,
                            style: AppTypography.bodySmall.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: AppSizes.space32),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'stay':
        return Icons.hotel_outlined;
      case 'explore':
        return Icons.explore_outlined;
      default:
        return Icons.event_outlined;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space24),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: AppColors.sunnyYellow,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space20),
            Text(
              'Something went wrong',
              style: AppTypography.headlineSmall.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.sunnyYellow,
                foregroundColor: colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space24,
                  vertical: AppSizes.space12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(
                'Retry',
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
