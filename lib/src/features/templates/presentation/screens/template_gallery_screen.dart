import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/app_router.dart';
import '../../../ads/native_ad_slots.dart';
import '../../../ads/presentation/widgets/native_ad_list_tile.dart';
import '../../data/models/template_model.dart';
import '../providers/templates_provider.dart';
import '../widgets/report_template_sheet.dart';
import '../widgets/template_detail_sheet.dart';
import '../widgets/use_template_dialog.dart';

/// Trip templates — the community gallery and your own.
class TemplateGalleryScreen extends ConsumerStatefulWidget {
  const TemplateGalleryScreen({super.key});

  @override
  ConsumerState<TemplateGalleryScreen> createState() =>
      _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends ConsumerState<TemplateGalleryScreen> {
  static const String _discover = 'Discover';
  static const String _mine = 'Mine';

  final _searchController = TextEditingController();
  String _tab = _discover;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _use(TripTemplateModel template) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => UseTemplateDialog(template: template),
    );

    if (result == null || !mounted) return;
    final tripId = result['id'] as String?;
    if (tripId != null) context.push('${AppRoutes.tripDetail}/$tripId');
  }

  Future<void> _fork(TripTemplateModel template) async {
    HapticFeedback.lightImpact();
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Save to your templates',
      body: [
        'This copies "${template.name}" into your own templates, where you '
            'can change it however you like.',
      ],
      confirmLabel: 'Save a copy',
    );
    if (!confirmed || !mounted) return;

    final forked = await ref
        .read(myTemplatesProvider.notifier)
        .forkTemplate(template.id);

    if (!mounted) return;
    showOdysseyMessage(
      context,
      forked == null ? 'Could not save that copy.' : 'Saved to your templates.',
    );
  }

  Future<void> _delete(TripTemplateModel template) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete template',
      body: [
        'This removes "${template.name}". Trips already built from it are '
            'not affected.',
      ],
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    await ref.read(myTemplatesProvider.notifier).deleteTemplate(template.id);
  }

  void _openDetail(TripTemplateModel template, {required bool owned}) {
    HapticFeedback.selectionClick();
    showTemplateDetail(
      context: context,
      template: template,
      onUse: () => _use(template),
      onSecondary: owned ? () => _delete(template) : () => _fork(template),
      secondaryLabel: owned ? 'Delete template' : 'Save a copy',
      // App Store Guideline 1.2 wants reporting and blocking reachable from
      // the content itself, not buried in settings — so they hang off the
      // detail sheet for anything someone else published.
      onReport: owned ? null : () => _moderate(template),
    );
  }

  Future<void> _moderate(TripTemplateModel template) async {
    final action = await showOdysseyPicker<String>(
      context: context,
      title: template.name,
      options: const ['Report this template', 'Block the author'],
      labelOf: (value) => value,
    );
    if (!mounted || action == null) return;

    if (action == 'Block the author') {
      await showBlockAuthorDialog(context, ref, template);
    } else {
      await showReportTemplateSheet(context: context, template: template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final discovering = _tab == _discover;

    final gallery = ref.watch(templateGalleryProvider);
    final mine = ref.watch(myTemplatesProvider);

    final templates = discovering ? gallery.templates : mine.templates;
    final isLoading = discovering ? gallery.isLoading : mine.isLoading;
    final error = discovering ? gallery.error : mine.error;
    final category = discovering
        ? gallery.selectedCategory
        : mine.selectedCategory;

    final slots = NativeAdSlots(templates.length);

    return OdysseyScaffold(
      body: RefreshIndicator(
        color: t.action,
        backgroundColor: Color.alphaBlend(t.card, t.canvas),
        onRefresh: () => discovering
            ? ref.read(templateGalleryProvider.notifier).refresh()
            : ref.read(myTemplatesProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.contentTop,
            AppSizes.screenPadding,
            AppSizes.scrollBottom,
          ),
          children: [
            ScreenHeader(onBack: () => context.pop()),
            const SizedBox(height: AppSizes.space20),
            Text(
              'Start from\nsomeone else',
              style: AppTypography.screenTitle.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space20),

            SegmentedControl(
              labels: const [_discover, _mine],
              selected: _tab,
              onSelected: (value) {
                HapticFeedback.selectionClick();
                setState(() => _tab = value);
              },
            ),
            const SizedBox(height: AppSizes.space16),

            if (discovering) ...[
              SearchPill(
                hint: 'Search templates',
                controller: _searchController,
                onChanged: (value) => ref
                    .read(templateGalleryProvider.notifier)
                    .search(value.isEmpty ? null : value),
              ),
              const SizedBox(height: AppSizes.space14),
            ],

            _CategoryChips(
              selected: category,
              onSelected: (value) => discovering
                  ? ref
                        .read(templateGalleryProvider.notifier)
                        .filterByCategory(value)
                  : ref
                        .read(myTemplatesProvider.notifier)
                        .filterByCategory(value),
            ),
            const SizedBox(height: AppSizes.space18),

            if (isLoading && templates.isEmpty)
              const Column(
                children: [
                  Skeleton.row(),
                  SizedBox(height: AppSizes.space10),
                  Skeleton.row(),
                ],
              )
            else if (error != null && templates.isEmpty)
              OdysseyErrorState.fromError(
                error,
                message: 'The template gallery could not be loaded.',
                onRetry: () => discovering
                    ? ref.read(templateGalleryProvider.notifier).refresh()
                    : ref.read(myTemplatesProvider.notifier).refresh(),
              )
            else if (templates.isEmpty)
              OdysseyEmptyState(
                icon: Icons.dashboard_customize_outlined,
                message: discovering
                    ? 'Nothing here under that filter.'
                    : 'You have no templates yet. Save a trip as one from its '
                          'options menu.',
              )
            else
              for (var i = 0; i < templates.length; i++) ...[
                if (slots.isAdAt(i)) ...[
                  const NativeAdListTile(),
                  const SizedBox(height: AppSizes.space10),
                ],
                _TemplateRow(
                  template: templates[i],
                  onTap: () => _openDetail(templates[i], owned: !discovering),
                ),
                const SizedBox(height: AppSizes.space10),
              ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final TemplateCategory? selected;
  final ValueChanged<TemplateCategory?> onSelected;

  static const String _all = 'All';

  @override
  Widget build(BuildContext context) {
    final labels = [_all, ...TemplateCategory.values.map((c) => c.displayName)];

    return ChipRow(
      labels: labels,
      selected: selected?.displayName ?? _all,
      activeStyle: ChipActiveStyle.action,
      padding: EdgeInsets.zero,
      onSelected: (label) => onSelected(
        label == _all
            ? null
            : TemplateCategory.values.firstWhere(
                (c) => c.displayName == label,
              ),
      ),
    );
  }
}

/// One template in the list.
///
/// Deliberately has no filled button. A lime call to action on every row is a
/// wall of accent, and a one-accent system spends its force that way — the
/// emphatic action lives on the detail sheet this row opens.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template, required this.onTap});

  final TripTemplateModel template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final structure = template.structure;

    final meta = [
      if (structure.durationDays != null) '${structure.durationDays} days',
      if (structure.activities.isNotEmpty)
        '${structure.activities.length} plans',
      if (structure.packingItems.isNotEmpty)
        '${structure.packingItems.length} to pack',
      if (template.useCount > 0) 'used ${template.useCount}×',
    ].join(' · ');

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusRow),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
          border: Border.all(color: t.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        template.name,
                        style: AppTypography.cardTitleXl.copyWith(
                          color: t.ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          style: AppTypography.rowMeta.copyWith(color: t.ink3),
                        ),
                      ],
                    ],
                  ),
                ),
                if (template.category != null) ...[
                  const SizedBox(width: AppSizes.space10),
                  MonoTag(template.category!.displayName),
                ],
              ],
            ),
            if (template.description != null &&
                template.description!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.space10),
              Text(
                template.description!,
                style: AppTypography.rowMeta.copyWith(color: t.ink2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
