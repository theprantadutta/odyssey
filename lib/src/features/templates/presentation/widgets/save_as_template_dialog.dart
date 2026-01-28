import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/subscription/presentation/providers/subscription_provider.dart';
import 'package:odyssey/src/features/subscription/presentation/screens/paywall_screen.dart';
import 'package:odyssey/src/features/templates/data/models/template_model.dart';
import 'package:odyssey/src/features/templates/presentation/providers/templates_provider.dart';

class SaveAsTemplateDialog extends ConsumerStatefulWidget {
  final String tripId;
  final String tripTitle;

  const SaveAsTemplateDialog({
    super.key,
    required this.tripId,
    required this.tripTitle,
  });

  @override
  ConsumerState<SaveAsTemplateDialog> createState() =>
      _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends ConsumerState<SaveAsTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  TemplateCategory? _selectedCategory;
  bool _isPublic = false;
  bool _includeActivities = true;
  bool _includePackingItems = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '${widget.tripTitle} Template');
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onPublicToggled(bool isPublic) {
    if (isPublic) {
      final isPremium = ref.read(isPremiumProvider);
      if (!isPremium) {
        PaywallUtils.showPaywall(
          context,
          featureName: 'Public Templates',
          customDescription: 'Share your templates with the community with Premium',
          featureIcon: Icons.public,
        );
        return;
      }
    }
    setState(() => _isPublic = isPublic);
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final request = TemplateFromTripRequest(
      tripId: widget.tripId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      isPublic: _isPublic,
      category: _selectedCategory,
      includeActivities: _includeActivities,
      includePackingItems: _includePackingItems,
    );

    final template = await ref
        .read(myTemplatesProvider.notifier)
        .createFromTrip(request);

    setState(() => _isSaving = false);

    if (template != null && mounted) {
      Navigator.of(context).pop(template);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template "${template.name}" created!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      child: Container(
        width: 400,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(AppSizes.space20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.space12),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderDream.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: const Icon(
                      Icons.bookmark_add_outlined,
                      color: AppColors.lavenderDream,
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: Text(
                      'Save as Template',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space20),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Template name',
                          hintText: 'Enter a name for this template',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.space16),

                      // Description field
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Describe what this template is for',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.space16),

                      // Category selector
                      Text(
                        'Category',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSizes.space8),
                      Wrap(
                        spacing: AppSizes.space8,
                        runSpacing: AppSizes.space8,
                        children: TemplateCategory.values.take(6).map((category) {
                          final isSelected = _selectedCategory == category;
                          return FilterChip(
                            label: Text('${category.icon} ${category.displayName}'),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = selected ? category : null;
                              });
                            },
                            selectedColor: AppColors.oceanTeal.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.oceanTeal,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSizes.space16),

                      // Include options
                      Text(
                        'Include in template',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSizes.space8),
                      CheckboxListTile(
                        value: _includeActivities,
                        onChanged: (value) =>
                            setState(() => _includeActivities = value ?? true),
                        title: const Text('Activities'),
                        subtitle: const Text('Include planned activities'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        value: _includePackingItems,
                        onChanged: (value) =>
                            setState(() => _includePackingItems = value ?? true),
                        title: const Text('Packing list'),
                        subtitle: const Text('Include packing items'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),

                      // Public toggle
                      SwitchListTile(
                        value: _isPublic,
                        onChanged: _onPublicToggled,
                        title: const Text('Share publicly'),
                        subtitle: const Text('Allow others to use this template'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.space20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _saveTemplate,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Template'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.lavenderDream,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
