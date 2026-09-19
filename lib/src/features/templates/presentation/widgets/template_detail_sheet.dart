import 'package:flutter/material.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/template_model.dart';

/// What a template actually contains, before you commit to building from it.
Future<void> showTemplateDetail({
  required BuildContext context,
  required TripTemplateModel template,
  required VoidCallback onUse,
  required VoidCallback onSecondary,
  required String secondaryLabel,
  VoidCallback? onReport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TemplateDetailSheet(
      template: template,
      onUse: onUse,
      onSecondary: onSecondary,
      secondaryLabel: secondaryLabel,
      onReport: onReport,
    ),
  );
}

class _TemplateDetailSheet extends StatelessWidget {
  const _TemplateDetailSheet({
    required this.template,
    required this.onUse,
    required this.onSecondary,
    required this.secondaryLabel,
    this.onReport,
  });

  final TripTemplateModel template;
  final VoidCallback onUse;
  final VoidCallback onSecondary;
  final String secondaryLabel;

  /// Null for a template the user owns — there is nothing to report to
  /// themselves.
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final structure = template.structure;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(t.sheet, t.canvas),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusSheet),
        ),
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.space24,
                  AppSizes.screenPadding,
                  AppSizes.space16,
                ),
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: EyebrowLabel(
                          template.category?.displayName ?? 'Template',
                        ),
                      ),
                      if (template.useCount > 0)
                        Text(
                          'used ${template.useCount}×',
                          style: AppTypography.rowMeta.copyWith(
                            color: t.ink3,
                          ),
                        ),
                      if (onReport != null) ...[
                        const SizedBox(width: AppSizes.space10),
                        CircleButton(
                          icon: Icons.more_horiz_rounded,
                          size: AppSizes.circleSm,
                          onPressed: () {
                            Navigator.of(context).pop();
                            onReport!();
                          },
                          semanticLabel: 'Report or block',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSizes.space12),
                  Text(
                    template.name,
                    style: AppTypography.statSmall.copyWith(color: t.ink),
                  ),
                  if (template.description != null &&
                      template.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space10),
                    Text(
                      template.description!,
                      style: AppTypography.subtitle.copyWith(color: t.ink2),
                    ),
                  ],
                  const SizedBox(height: AppSizes.space20),

                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          value: '${structure.durationDays ?? 0}',
                          label: 'days',
                        ),
                      ),
                      const SizedBox(width: AppSizes.space10),
                      Expanded(
                        child: StatCard(
                          value: '${structure.activities.length}',
                          label: 'plans',
                        ),
                      ),
                      const SizedBox(width: AppSizes.space10),
                      Expanded(
                        child: StatCard(
                          value: '${structure.packingItems.length}',
                          label: 'to pack',
                        ),
                      ),
                    ],
                  ),

                  if (structure.activities.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space20),
                    const EyebrowLabel('What is planned'),
                    const SizedBox(height: AppSizes.space12),
                    GroupedCard(
                      children: [
                        // Only the first handful: this is a preview of the
                        // shape, not the itinerary itself.
                        for (final activity in structure.activities.take(6))
                          _PreviewRow(
                            title: activity.title,
                            meta: [
                              activity.category,
                              if (activity.location != null &&
                                  activity.location!.isNotEmpty)
                                activity.location!,
                            ].join(' · '),
                          ),
                      ],
                    ),
                    if (structure.activities.length > 6) ...[
                      const SizedBox(height: AppSizes.space8),
                      Text(
                        'and ${structure.activities.length - 6} more',
                        style: AppTypography.rowMeta.copyWith(color: t.ink3),
                      ),
                    ],
                  ],

                  if (structure.packingItems.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space20),
                    const EyebrowLabel('What to pack'),
                    const SizedBox(height: AppSizes.space12),
                    Wrap(
                      spacing: AppSizes.space8,
                      runSpacing: AppSizes.space8,
                      children: [
                        for (final item in structure.packingItems.take(12))
                          OdysseyChip(label: item.name, selected: false),
                      ],
                    ),
                  ],

                  if (structure.suggestedTags.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.space20),
                    const EyebrowLabel('Tags'),
                    const SizedBox(height: AppSizes.space12),
                    Wrap(
                      spacing: AppSizes.space8,
                      runSpacing: AppSizes.space8,
                      children: [
                        for (final tag in structure.suggestedTags)
                          OdysseyChip(label: tag, selected: false),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                0,
                AppSizes.screenPadding,
                AppSizes.space24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PillButton(
                    label: 'Build a trip from this',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onUse();
                    },
                  ),
                  const SizedBox(height: AppSizes.space10),
                  PillButton(
                    label: secondaryLabel,
                    style: PillStyle.outline,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onSecondary();
                    },
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.rowLabel.copyWith(color: t.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(width: AppSizes.space10),
            Flexible(
              child: Text(
                meta,
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
