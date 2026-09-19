import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../data/models/template_model.dart';
import '../providers/templates_provider.dart';

/// Turns a template into a real trip: a name and the dates it will run.
class UseTemplateDialog extends ConsumerStatefulWidget {
  const UseTemplateDialog({super.key, required this.template});

  final TripTemplateModel template;

  @override
  ConsumerState<UseTemplateDialog> createState() => _UseTemplateDialogState();
}

class _UseTemplateDialogState extends ConsumerState<UseTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    final structure = widget.template.structure;
    _titleController = TextEditingController(
      text: structure.defaultTitle ?? widget.template.name,
    );
    _descriptionController = TextEditingController(
      text: structure.defaultDescription ?? '',
    );

    // The template knows how long it runs, so the end date arrives filled in.
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

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _startDate = picked;
      // Keep the template's own length rather than letting the range invert.
      final duration = widget.template.structure.durationDays;
      if (duration != null) {
        _endDate = picked.add(Duration(days: duration));
      } else if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked.add(const Duration(days: 1));
      }
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 1)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    final description = _descriptionController.text.trim();
    final result = await ref
        .read(templateGalleryProvider.notifier)
        .useTemplate(
          TripFromTemplateRequest(
            templateId: widget.template.id,
            title: _titleController.text.trim(),
            startDate: _startDate.toIso8601String().split('T').first,
            endDate: _endDate?.toIso8601String().split('T').first,
            description: description.isEmpty ? null : description,
          ),
        );

    if (!mounted) return;
    setState(() => _isCreating = false);

    if (result != null) {
      Navigator.of(context).pop(result);
      showOdysseyMessage(context, 'Trip created from the template.');
      return;
    }

    showOdysseyMessage(context, 'Could not build a trip from that template.');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final nights = TripFormat.nights(_startDate, _endDate);

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: EyebrowLabel('Build from')),
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
                widget.template.name,
                style: AppTypography.statSmall.copyWith(color: t.ink),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSizes.space20),

              FieldCard(
                label: 'Trip name',
                controller: _titleController,
                hint: 'What will you call it?',
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    Validators.required(value, fieldName: 'Trip name'),
              ),
              const SizedBox(height: AppSizes.space12),

              Row(
                children: [
                  Expanded(
                    child: ValueCard(
                      label: 'From',
                      value: TripFormat.shortDate(_startDate),
                      onTap: _pickStart,
                    ),
                  ),
                  const SizedBox(width: AppSizes.space10),
                  Expanded(
                    child: ValueCard(
                      label: 'To',
                      value: _endDate == null
                          ? null
                          : TripFormat.shortDate(_endDate),
                      onTap: _pickEnd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space12),

              FieldCard(
                label: 'Notes',
                controller: _descriptionController,
                hint: 'Optional',
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSizes.space20),

              PillButton(
                label: _titleController.text.trim().isEmpty
                    ? 'Name the trip'
                    : (_endDate == null
                          ? 'Create the trip'
                          : 'Create · $nights '
                                '${nights == 1 ? 'night' : 'nights'}'),
                isLoading: _isCreating,
                onPressed:
                    _titleController.text.trim().isEmpty || _isCreating
                    ? null
                    : _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
