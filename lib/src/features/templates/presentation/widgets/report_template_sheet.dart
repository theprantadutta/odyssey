import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/template_model.dart';
import '../providers/templates_provider.dart';

/// Reporting and blocking for templates other people published.
///
/// App Store Guideline 1.2 requires both on any app carrying user-generated
/// content, and requires them to be reachable from the content itself rather
/// than buried in settings — a reviewer looks for exactly this.
Future<void> showReportTemplateSheet({
  required BuildContext context,
  required TripTemplateModel template,
}) {
  return showModalBottomSheet<void>(
    // Pushed on the root navigator so the sheet covers the tab bar. The
    // bar belongs to the shell's Scaffold, which sits outside a branch
    // navigator - present it there and the bar paints over the sheet,
    // undimmed, with a dead strip of screen beneath it.
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReportTemplateSheet(template: template),
  );
}

class _ReportTemplateSheet extends ConsumerStatefulWidget {
  const _ReportTemplateSheet({required this.template});

  final TripTemplateModel template;

  @override
  ConsumerState<_ReportTemplateSheet> createState() =>
      _ReportTemplateSheetState();
}

class _ReportTemplateSheetState extends ConsumerState<_ReportTemplateSheet> {
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
      await ref
          .read(templateGalleryProvider.notifier)
          .reportTemplate(
            templateId: widget.template.id,
            reason: _reason!,
            details: _detailsController.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      HapticFeedback.mediumImpact();
      showOdysseyMessage(context, 'Thanks — we will review this template.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      HapticFeedback.heavyImpact();
      showOdysseyError(context, 'That report did not send.', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.space24,
        AppSizes.screenPadding,
        AppSizes.space24 + MediaQuery.viewInsetsOf(context).bottom,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EyebrowLabel('Report'),
            const SizedBox(height: AppSizes.space12),
            Text(
              'What is wrong with this?',
              style: AppTypography.statSmall.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space10),
            Text(
              'Reported templates are reviewed, and removed if they break the '
              'rules.',
              style: AppTypography.subtitle.copyWith(color: t.ink2),
            ),
            const SizedBox(height: AppSizes.space18),

            // Chips rather than radio rows: this system has no radio, and the
            // reasons are short enough to wrap.
            Wrap(
              spacing: AppSizes.space8,
              runSpacing: AppSizes.space8,
              children: [
                for (final reason in _reasons)
                  OdysseyChip(
                    label: reason,
                    selected: reason == _reason,
                    activeStyle: ChipActiveStyle.action,
                    onTap: _submitting
                        ? null
                        : () => setState(() => _reason = reason),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.space16),

            FieldCard(
              label: 'Anything else',
              controller: _detailsController,
              hint: 'Optional',
              maxLines: 3,
              minLines: 1,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.space20),

            PillButton(
              label: _reason == null ? 'Pick a reason' : 'Send the report',
              isLoading: _submitting,
              onPressed: _reason == null || _submitting ? null : _submit,
            ),
            const SizedBox(height: AppSizes.space10),
            PillButton(
              label: 'Cancel',
              style: PillStyle.outline,
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirms blocking, then blocks.
///
/// Separate from reporting: reporting is about the content, blocking is about
/// never seeing that author again.
Future<void> showBlockAuthorDialog(
  BuildContext context,
  WidgetRef ref,
  TripTemplateModel template,
) async {
  final confirmed = await showOdysseyConfirm(
    context: context,
    title: 'Block this author?',
    body: [
      'You will not see any templates from whoever published '
          '"${template.name}" again. They are not told, and you can undo this '
          'later.',
    ],
    confirmLabel: 'Block',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(templateGalleryProvider.notifier).blockUser(template.userId);
    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    showOdysseyMessage(
      context,
      'Blocked. Their templates are hidden from your gallery.',
    );
  } catch (e) {
    if (!context.mounted) return;
    HapticFeedback.heavyImpact();
    showOdysseyError(context, 'Could not block that author.', error: e);
  }
}
