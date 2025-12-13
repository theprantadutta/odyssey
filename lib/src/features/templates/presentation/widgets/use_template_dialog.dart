import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odyssey/src/common/theme/app_colors.dart';
import 'package:odyssey/src/common/theme/app_sizes.dart';
import 'package:odyssey/src/features/templates/data/models/template_model.dart';
import 'package:odyssey/src/features/templates/presentation/providers/templates_provider.dart';

class UseTemplateDialog extends ConsumerStatefulWidget {
  final TripTemplateModel template;

  const UseTemplateDialog({
    super.key,
    required this.template,
  });

  @override
  ConsumerState<UseTemplateDialog> createState() => _UseTemplateDialogState();
}

class _UseTemplateDialogState extends ConsumerState<UseTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final structure = widget.template.structure;
    _titleController = TextEditingController(
      text: structure.defaultTitle ?? '',
    );
    _descriptionController = TextEditingController(
      text: structure.defaultDescription ?? '',
    );

    // Set default end date based on template duration
    if (structure.durationDays != null) {
      _endDate = _startDate.add(Duration(days: structure.durationDays!));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Adjust end date if needed
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
        // Auto-set end date based on template duration
        if (_endDate == null && widget.template.structure.durationDays != null) {
          _endDate = _startDate.add(
            Duration(days: widget.template.structure.durationDays!),
          );
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 1)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    final request = TripFromTemplateRequest(
      templateId: widget.template.id,
      title: _titleController.text.trim(),
      startDate: _startDate.toIso8601String().split('T').first,
      endDate: _endDate?.toIso8601String().split('T').first,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    final result =
        await ref.read(templateGalleryProvider.notifier).useTemplate(request);

    setState(() => _isCreating = false);

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip created from "${widget.template.name}"!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create trip from template'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final structure = widget.template.structure;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(AppSizes.space20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                        color: AppColors.oceanTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                      child: Text(
                        widget.template.category?.icon ?? '📋',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Template',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.template.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space20),

                // Template info
                if (structure.activities.isNotEmpty ||
                    structure.packingItems.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSizes.space12),
                    decoration: BoxDecoration(
                      color: AppColors.warmGray,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.oceanTeal,
                        ),
                        const SizedBox(width: AppSizes.space8),
                        Expanded(
                          child: Text(
                            'This will create a trip with ${structure.activities.length} activities and ${structure.packingItems.length} packing items',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),
                ],

                // Title field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Trip title',
                    hintText: 'Enter a name for your trip',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
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
                    hintText: 'Add a description for your trip',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.space16),

                // Date selectors
                Text(
                  'Trip Dates',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),

                Row(
                  children: [
                    Expanded(
                      child: _DateButton(
                        label: 'Start',
                        date: _startDate,
                        onTap: _selectStartDate,
                      ),
                    ),
                    const SizedBox(width: AppSizes.space12),
                    Expanded(
                      child: _DateButton(
                        label: 'End',
                        date: _endDate,
                        hint: 'Optional',
                        onTap: _selectEndDate,
                      ),
                    ),
                  ],
                ),

                if (structure.durationDays != null) ...[
                  const SizedBox(height: AppSizes.space8),
                  Text(
                    'Suggested duration: ${structure.durationDays} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: AppSizes.space24),

                // Create button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCreating ? null : _createTrip,
                    icon: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isCreating ? 'Creating...' : 'Create Trip'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.oceanTeal,
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
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String? hint;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.date,
    this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.mutedGray),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  date != null ? _formatDate(date!) : (hint ?? 'Select'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: date != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
