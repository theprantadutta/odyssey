import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../settings/presentation/widgets/settings_rows.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../../subscription/presentation/utils/limit_checker.dart';
import '../../data/models/template_model.dart';
import '../providers/templates_provider.dart';

/// Turns a finished trip into a template someone can start from.
class SaveAsTemplateDialog extends ConsumerStatefulWidget {
  const SaveAsTemplateDialog({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  final String tripId;
  final String tripTitle;

  @override
  ConsumerState<SaveAsTemplateDialog> createState() =>
      _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends ConsumerState<SaveAsTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: '${widget.tripTitle} template',
  );
  final _descriptionController = TextEditingController();

  TemplateCategory? _category;
  bool _isPublic = false;
  bool _includeActivities = true;
  bool _includePackingItems = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _setPublic(bool isPublic) {
    if (isPublic && !ref.read(isPremiumProvider)) {
      PaywallUtils.showPaywall(
        context,
        featureName: 'Public Templates',
        customDescription:
            'Put your trips in the gallery for other people to build from.',
        featureIcon: Icons.public,
      );
      return;
    }
    setState(() => _isPublic = isPublic);
  }

  Future<void> _save() async {
    final currentCount = ref.read(myTemplatesProvider).templates.length;
    final canCreate = await LimitChecker.canCreateTemplate(
      context,
      ref,
      currentCount: currentCount,
    );
    if (!canCreate || !mounted) return;

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final description = _descriptionController.text.trim();
    final template = await ref
        .read(myTemplatesProvider.notifier)
        .createFromTrip(
          TemplateFromTripRequest(
            tripId: widget.tripId,
            name: _nameController.text.trim(),
            description: description.isEmpty ? null : description,
            isPublic: _isPublic,
            category: _category,
            includeActivities: _includeActivities,
            includePackingItems: _includePackingItems,
          ),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (template != null) {
      Navigator.of(context).pop(template);
      showOdysseyMessage(context, 'Saved as a template.');
      return;
    }

    showOdysseyMessage(context, 'Could not save that template.');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSizes.space20),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space20),
        decoration: BoxDecoration(
          color: Color.alphaBlend(t.sheet, t.canvas),
          borderRadius: BorderRadius.circular(AppSizes.radiusPanel),
          border: Border.all(color: t.hairline),
        ),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: EyebrowLabel('Save as template')),
                    CircleButton(
                      glyph: '✕',
                      size: AppSizes.circleSm,
                      onPressed: () => Navigator.of(context).pop(),
                      semanticLabel: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space10),
                Text(
                  widget.tripTitle,
                  style: AppTypography.statSmall.copyWith(color: t.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.space20),

                FieldCard(
                  label: 'Template name',
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      Validators.required(value, fieldName: 'Name'),
                ),
                const SizedBox(height: AppSizes.space12),
                FieldCard(
                  label: 'Description',
                  controller: _descriptionController,
                  hint: 'What is this good for?',
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: AppSizes.space18),

                const EyebrowLabel('Category'),
                const SizedBox(height: AppSizes.space12),
                ChipWrap(
                  labels: TemplateCategory.values
                      .map((c) => c.displayName)
                      .toList(),
                  selected: _category?.displayName,
                  onSelected: (label) => setState(() {
                    final picked = TemplateCategory.values.firstWhere(
                      (c) => c.displayName == label,
                    );
                    _category = _category == picked ? null : picked;
                  }),
                ),
                const SizedBox(height: AppSizes.space18),

                GroupedCard(
                  children: [
                    SettingsToggleRow(
                      icon: Icons.event_outlined,
                      label: 'Include the plans',
                      value: _includeActivities,
                      onChanged: (v) =>
                          setState(() => _includeActivities = v),
                    ),
                    SettingsToggleRow(
                      icon: Icons.luggage_outlined,
                      label: 'Include the packing list',
                      circleChip: true,
                      value: _includePackingItems,
                      onChanged: (v) =>
                          setState(() => _includePackingItems = v),
                    ),
                    SettingsToggleRow(
                      icon: Icons.public_outlined,
                      label: 'Share publicly',
                      meta: 'Anyone can find and build from it',
                      value: _isPublic,
                      onChanged: _setPublic,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space20),

                PillButton(
                  label: _nameController.text.trim().isEmpty
                      ? 'Name the template'
                      : 'Save the template',
                  isLoading: _isSaving,
                  onPressed:
                      _nameController.text.trim().isEmpty || _isSaving
                      ? null
                      : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
