import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/location_picker_button.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../subscription/presentation/utils/limit_checker.dart';
import '../../data/models/activity_model.dart';
import '../../../trips/presentation/providers/trips_provider.dart';
import '../providers/activities_provider.dart';

/// Add or edit a plan.
class ActivityFormScreen extends ConsumerStatefulWidget {
  const ActivityFormScreen({
    super.key,
    required this.tripId,
    this.activity,
  });

  final String tripId;
  final ActivityModel? activity;

  @override
  ConsumerState<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> {
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  ActivityCategory _category = ActivityCategory.explore;
  bool _isLoading = false;

  bool get _isEditing => widget.activity != null;

  @override
  void initState() {
    super.initState();
    if (widget.activity != null) {
      _initializeWith(widget.activity!);
    } else {
      _scheduledDate = _defaultDay();
      _scheduledTime = const TimeOfDay(hour: 12, minute: 0);
    }
  }

  /// The day a new plan lands on before the user says otherwise.
  ///
  /// Today, but only when today is actually part of the trip. A trip four days
  /// out opened its plan form on today's date, which is outside the trip
  /// altogether - so the first plan anyone added, without noticing, sat in a
  /// day the itinerary does not have.
  DateTime _defaultDay() {
    final now = DateTime.now();

    final trip = ref
        .read(tripsProvider)
        .trips
        .where((t) => t.id == widget.tripId)
        .firstOrNull;

    final start = TripFormat.parse(trip?.startDate);
    final end = TripFormat.parse(trip?.endDate);
    if (start == null) return now;

    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(start)) return start;
    if (end != null && today.isAfter(end)) return start;
    return today;
  }

  void _initializeWith(ActivityModel activity) {
    _titleController.text = activity.title;
    _descriptionController.text = activity.description ?? '';
    _latitudeController.text = activity.latitude?.toString() ?? '';
    _longitudeController.text = activity.longitude?.toString() ?? '';
    _category = ActivityCategory.values.firstWhere(
      (c) => c.name == activity.category,
      orElse: () => ActivityCategory.explore,
    );

    final scheduled = DateTime.tryParse(activity.scheduledTime)?.toLocal();
    if (scheduled != null) {
      _scheduledDate = scheduled;
      _scheduledTime = TimeOfDay.fromDateTime(scheduled);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _scheduledDate != null &&
      _scheduledTime != null &&
      !_isLoading;

  String get _submitLabel {
    if (_titleController.text.trim().isEmpty) return 'Name the plan';
    if (_scheduledDate == null) return 'Pick a day';
    if (_scheduledTime == null) return 'Pick a time';
    return _isEditing ? 'Save changes' : 'Add to the trip';
  }

  Future<void> _handleSubmit() async {
    if (widget.activity == null) {
      final currentCount =
          ref.read(tripActivitiesProvider(widget.tripId)).activities.length;
      final canCreate = await LimitChecker.canCreateActivity(
        context,
        ref,
        currentCount: currentCount,
      );
      if (!canCreate) return;

      // The limit check shows its own dialog and awaits the answer, so this
      // widget can be gone by the time it returns.
      if (!mounted) return;
    }

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_scheduledDate == null || _scheduledTime == null) {
      HapticFeedback.heavyImpact();
      showOdysseyMessage(context, 'Pick a day and a time.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final scheduled = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );

      final description = _descriptionController.text.trim();
      final latitude = _latitudeController.text.trim();
      final longitude = _longitudeController.text.trim();

      if (widget.activity == null) {
        await ref
            .read(tripActivitiesProvider(widget.tripId).notifier)
            .createActivity(
              ActivityRequest(
                tripId: widget.tripId,
                title: _titleController.text.trim(),
                description: description.isEmpty ? null : description,
                scheduledTime: scheduled.toUtc().toIso8601String(),
                category: _category.name,
                latitude: latitude.isEmpty ? null : double.tryParse(latitude),
                longitude: longitude.isEmpty ? null : double.tryParse(longitude),
              ),
            );
      } else {
        await ref
            .read(tripActivitiesProvider(widget.tripId).notifier)
            .updateActivity(widget.activity!.id, {
              'title': _titleController.text.trim(),
              'description': description.isEmpty ? null : description,
              'scheduled_time': scheduled.toUtc().toIso8601String(),
              'category': _category.name,
              'latitude': latitude.isEmpty ? null : latitude,
              'longitude': longitude.isEmpty ? null : longitude,
            });
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showOdysseyMessage(
        context,
        widget.activity == null ? 'Plan added.' : 'Plan updated.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      showOdysseyError(context, 'That did not save.', error: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete plan',
      body: [
        'This removes "${widget.activity!.title}" from the day. It cannot be '
            'undone.',
      ],
      confirmLabel: 'Delete plan',
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(tripActivitiesProvider(widget.tripId).notifier)
        .deleteActivity(widget.activity!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return OdysseyFormScreen(
      formKey: _formKey,
      onChanged: () => setState(() {}),
      caption: _isEditing ? 'Editing' : null,
      title: _isEditing ? 'Edit plan' : 'New plan',
      submitLabel: _submitLabel,
      onSubmit: _canSubmit ? _handleSubmit : null,
      isLoading: _isLoading,
      secondaryLabel: _isEditing ? 'Delete plan' : null,
      onSecondary: _isEditing ? _handleDelete : null,
      children: [
        FieldCard(
          label: 'What is it',
          controller: _titleController,
          hint: 'Fushimi Inari at dawn',
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: (value) => Validators.required(value, fieldName: 'Title'),
        ),
        const SizedBox(height: AppSizes.space12),
        FieldCard(
          label: 'Notes',
          controller: _descriptionController,
          hint: 'Anything worth remembering',
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSizes.space12),

        Row(
          children: [
            Expanded(
              child: ValueCard(
                label: 'Day',
                value: _scheduledDate == null
                    ? null
                    : TripFormat.shortDate(_scheduledDate),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: AppSizes.space10),
            Expanded(
              child: ValueCard(
                label: 'Time',
                value: _scheduledTime == null
                    ? null
                    : _timeFormat.format(
                        DateTime(
                          2000,
                          1,
                          1,
                          _scheduledTime!.hour,
                          _scheduledTime!.minute,
                        ),
                      ),
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space20),

        FormGroup(
          label: 'Kind',
          child: ChipWrap(
            labels: ActivityCategory.values.map((c) => c.displayName).toList(),
            selected: _category.displayName,
            onSelected: (label) => setState(() {
              _category = ActivityCategory.values.firstWhere(
                (c) => c.displayName == label,
              );
            }),
          ),
        ),
        const SizedBox(height: AppSizes.space20),

        FormGroup(
          label: 'Where',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocationPickerButton(
                latitudeController: _latitudeController,
                longitudeController: _longitudeController,
                isEnabled: !_isLoading,
                onLocationFetched: () => setState(() {}),
              ),
              const SizedBox(height: AppSizes.space10),
              Row(
                children: [
                  Expanded(
                    child: FieldCard(
                      label: 'Latitude',
                      controller: _latitudeController,
                      hint: 'Optional',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space10),
                  Expanded(
                    child: FieldCard(
                      label: 'Longitude',
                      controller: _longitudeController,
                      hint: 'Optional',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
