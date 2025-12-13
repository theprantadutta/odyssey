import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/templates/data/models/template_model.dart';
import 'package:odyssey/src/features/templates/presentation/providers/templates_provider.dart';
import 'package:odyssey/src/features/templates/presentation/widgets/template_card.dart';
import 'package:odyssey/src/features/templates/presentation/widgets/use_template_dialog.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Templates'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Templates'),
          ],
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
    final galleryState = ref.watch(templateGalleryProvider);

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(AppSizes.space16),
          child: TextField(
            controller: widget.searchController,
            decoration: InputDecoration(
              hintText: 'Search templates...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: widget.searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.searchController.clear();
                        ref.read(templateGalleryProvider.notifier).search(null);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
            onSubmitted: (value) {
              ref.read(templateGalleryProvider.notifier).search(value);
            },
          ),
        ),

        // Category filter
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _selectedCategory == null,
                onSelected: (_) {
                  setState(() => _selectedCategory = null);
                  ref
                      .read(templateGalleryProvider.notifier)
                      .filterByCategory(null);
                },
              ),
              const SizedBox(width: AppSizes.space8),
              ...TemplateCategory.values.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSizes.space8),
                  child: FilterChip(
                    label: Text('${category.icon} ${category.displayName}'),
                    selected: _selectedCategory == category,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                      ref
                          .read(templateGalleryProvider.notifier)
                          .filterByCategory(category);
                    },
                    selectedColor: AppColors.oceanTeal.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.oceanTeal,
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: AppSizes.space8),

        // Templates list
        Expanded(
          child: galleryState.isLoading
              ? const Center(child: CircularProgressIndicator())
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
                          onRefresh: () => ref
                              .read(templateGalleryProvider.notifier)
                              .refresh(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSizes.space16),
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
                                  showActions: true,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      // Navigate to the created trip
      final tripId = result['id'] as String?;
      if (tripId != null) {
        context.push('/trips/$tripId');
      }
    }
  }
}

class _MyTemplatesTab extends ConsumerWidget {
  const _MyTemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTemplatesState = ref.watch(myTemplatesProvider);

    if (myTemplatesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(myTemplatesProvider.notifier).deleteTemplate(template.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${template.name}" deleted'),
            backgroundColor: AppColors.success,
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
    final structure = template.structure;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(AppSizes.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.space20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.space12),
                    decoration: BoxDecoration(
                      color: AppColors.oceanTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Text(
                      template.category?.icon ?? '📋',
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
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (template.category != null)
                          Text(
                            template.category!.displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.space24),
              const Divider(),
              const SizedBox(height: AppSizes.space16),

              // Stats
              Text(
                'Template Contents',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.space12),

              Wrap(
                spacing: AppSizes.space12,
                runSpacing: AppSizes.space8,
                children: [
                  if (structure.durationDays != null)
                    _InfoChip(
                      icon: Icons.calendar_today_outlined,
                      label: '${structure.durationDays} days',
                    ),
                  if (structure.activities.isNotEmpty)
                    _InfoChip(
                      icon: Icons.checklist_outlined,
                      label: '${structure.activities.length} activities',
                    ),
                  if (structure.packingItems.isNotEmpty)
                    _InfoChip(
                      icon: Icons.luggage_outlined,
                      label: '${structure.packingItems.length} packing items',
                    ),
                  _InfoChip(
                    icon: Icons.trending_up_outlined,
                    label: '${template.useCount} uses',
                  ),
                ],
              ),

              // Activities list
              if (structure.activities.isNotEmpty) ...[
                const SizedBox(height: AppSizes.space24),
                Text(
                  'Included Activities',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                ...structure.activities.take(5).map((activity) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warmGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getCategoryIcon(activity.category),
                        size: 20,
                        color: AppColors.oceanTeal,
                      ),
                    ),
                    title: Text(activity.title),
                    subtitle: activity.location != null
                        ? Text(
                            activity.location!,
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        : null,
                  );
                }),
                if (structure.activities.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.space8),
                    child: Text(
                      '+${structure.activities.length - 5} more activities',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],

              // Tips
              if (structure.tips.isNotEmpty) ...[
                const SizedBox(height: AppSizes.space24),
                Text(
                  'Tips',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                ...structure.tips.map((tip) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.space8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: AppColors.goldenGlow,
                        ),
                        const SizedBox(width: AppSizes.space8),
                        Expanded(
                          child: Text(
                            tip,
                            style: theme.textTheme.bodySmall,
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

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space8,
      ),
      decoration: BoxDecoration(
        color: AppColors.warmGray,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
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
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space20),
              decoration: BoxDecoration(
                color: AppColors.oceanTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.oceanTeal,
              ),
            ),
            const SizedBox(height: AppSizes.space20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
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
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.space16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
