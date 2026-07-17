import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/template_model.dart';
import '../providers/templates_provider.dart';

/// Reporting and blocking for templates other people published.
///
/// App Store Guideline 1.2 requires both on any app carrying user-generated content,
/// and requires them to be reachable from the content itself rather than buried in
/// settings - a reviewer looks for exactly this.
class ReportTemplateSheet extends ConsumerStatefulWidget {
  final TripTemplateModel template;

  const ReportTemplateSheet({super.key, required this.template});

  @override
  ConsumerState<ReportTemplateSheet> createState() => _ReportTemplateSheetState();
}

class _ReportTemplateSheetState extends ConsumerState<ReportTemplateSheet> {
  static const List<String> _reasons = [
    'Offensive or abusive language',
    'Sexual or adult content',
    'Violence or hate speech',
    'Spam or advertising',
    'Misleading or harmful advice',
    'Something else',
  ];

  String? _reason;
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(templateGalleryProvider.notifier).reportTemplate(
            templateId: widget.template.id,
            reason: _reason!,
            details: _detailsController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks — we\'ll review this template.'),
          backgroundColor: AppColors.oceanTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not report: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.space24,
        right: AppSizes.space24,
        top: AppSizes.space24,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.space24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report template',
            style: AppTypography.headlineSmall.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.space4),
          Text(
            'Tell us what\'s wrong with "${widget.template.name}". Reported templates are reviewed, and removed if they break the rules.',
            style: AppTypography.bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSizes.space16),

          RadioGroup<String>(
            groupValue: _reason,
            // RadioGroup wants a non-nullable callback, so the disabled case is
            // handled here rather than by passing null.
            onChanged: (v) {
              if (_submitting) return;
              setState(() => _reason = v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _reasons
                  .map(
                    (reason) => RadioListTile<String>(
                      value: reason,
                      title: Text(reason, style: AppTypography.bodyMedium),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.coralBurst,
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: AppSizes.space8),
          TextField(
            controller: _detailsController,
            enabled: !_submitting,
            maxLines: 2,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Anything else we should know? (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          ),

          const SizedBox(height: AppSizes.space8),
          Row(
            children: [
              TextButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: AppTypography.labelLarge.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_reason == null || _submitting) ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.coralBurst),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Report'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Confirms blocking, then blocks. Separate from reporting: reporting is about the
/// content, blocking is about never seeing that author again.
Future<void> showBlockAuthorDialog(
  BuildContext context,
  WidgetRef ref,
  TripTemplateModel template,
) async {
  final colorScheme = Theme.of(context).colorScheme;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusXl)),
      title: Text(
        'Block this author?',
        style: AppTypography.headlineSmall.copyWith(color: colorScheme.onSurface),
      ),
      content: Text(
        'You won\'t see any templates from whoever published "${template.name}" again. '
        'They aren\'t told, and you can undo this later.',
        style: AppTypography.bodyMedium.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: AppTypography.labelLarge.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.coralBurst),
          child: Text(
            'Block',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.coralBurst,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(templateGalleryProvider.notifier).blockUser(template.userId);
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Blocked. Their templates are hidden from your gallery.'),
        backgroundColor: AppColors.oceanTeal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not block: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
