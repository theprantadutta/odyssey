import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/animations/animated_widgets/animated_button.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/location_picker_button.dart';
import '../../data/models/activity_model.dart';
import '../providers/activities_provider.dart';

class ActivityFormScreen extends ConsumerStatefulWidget {
  final String tripId;
  final ActivityModel? activity;

  const ActivityFormScreen({
    super.key,
    required this.tripId,
    this.activity,
  });

  @override
  ConsumerState<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends ConsumerState<ActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  ActivityCategory _category = ActivityCategory.explore;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.activity != null) {
      _initializeWithActivity(widget.activity!);
    } else {
      // Default to today at noon for new activities
      _scheduledDate = DateTime.now();
      _scheduledTime = const TimeOfDay(hour: 12, minute: 0);
    }
  }

  void _initializeWithActivity(ActivityModel activity) {
    _titleController.text = activity.title;
    _descriptionController.text = activity.description ?? '';
    _latitudeController.text = activity.latitude?.toString() ?? '';
    _longitudeController.text = activity.longitude?.toString() ?? '';

    final scheduledDateTime = DateTime.tryParse(activity.scheduledTime);
    if (scheduledDateTime != null) {
      final localDateTime = scheduledDateTime.toLocal();
      _scheduledDate = localDateTime;
      _scheduledTime = TimeOfDay.fromDateTime(localDateTime);
    }

    _category = ActivityCategory.values.firstWhere(
      (c) => c.name == activity.category.toLowerCase(),
      orElse: () => ActivityCategory.explore,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sunnyYellow,
              onPrimary: AppColors.charcoal,
              onSurface: AppColors.charcoal,
              surface: AppColors.snowWhite,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppColors.snowWhite),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _scheduledDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    HapticFeedback.selectionClick();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sunnyYellow,
              onPrimary: AppColors.charcoal,
              onSurface: AppColors.charcoal,
              surface: AppColors.snowWhite,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: AppColors.snowWhite),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.lightImpact();
      setState(() {
        _scheduledTime = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_scheduledDate == null || _scheduledTime == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: AppSizes.space12),
              Text('Please select date and time'),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Combine date and time
      final scheduledDateTime = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );

      final request = ActivityRequest(
        tripId: widget.tripId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        scheduledTime: scheduledDateTime.toUtc().toIso8601String(),
        category: _category.name,
        latitude: _latitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_latitudeController.text.trim()),
        longitude: _longitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_longitudeController.text.trim()),
      );

      if (widget.activity == null) {
        await ref
            .read(tripActivitiesProvider(widget.tripId).notifier)
            .createActivity(request);
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: AppSizes.space12),
                  Text('Activity created successfully!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        await ref
            .read(tripActivitiesProvider(widget.tripId).notifier)
            .updateActivity(widget.activity!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'scheduled_time': scheduledDateTime.toUtc().toIso8601String(),
          'category': _category.name,
          'latitude': _latitudeController.text.trim().isEmpty
              ? null
              : _latitudeController.text.trim(),
          'longitude': _longitudeController.text.trim().isEmpty
              ? null
              : _longitudeController.text.trim(),
        });
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: AppSizes.space12),
                  Text('Activity updated successfully!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloudGray,
      appBar: AppBar(
        backgroundColor: AppColors.cloudGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.charcoal),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          widget.activity == null ? 'Add Activity' : 'Edit Activity',
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.charcoal,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.space24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Info Card
              _buildCard(
                title: 'Activity Info',
                icon: Icons.info_outline_rounded,
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Activity Title',
                    hint: 'e.g., Visit Eiffel Tower',
                    icon: Icons.title_rounded,
                    validator: (value) =>
                        Validators.required(value, fieldName: 'Title'),
                  ),
                  const SizedBox(height: AppSizes.space16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description (Optional)',
                    hint: 'Add notes or details...',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Category Card
              _buildCard(
                title: 'Category',
                icon: Icons.category_rounded,
                children: [
                  _buildCategorySelector(),
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Schedule Card
              _buildCard(
                title: 'Schedule',
                icon: Icons.schedule_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateButton(
                          label: 'Date',
                          value: _scheduledDate != null
                              ? DateFormat('MMM dd, yyyy').format(_scheduledDate!)
                              : 'Select',
                          icon: Icons.calendar_today_rounded,
                          onTap: () => _selectDate(context),
                          isSelected: _scheduledDate != null,
                        ),
                      ),
                      const SizedBox(width: AppSizes.space16),
                      Expanded(
                        child: _buildDateButton(
                          label: 'Time',
                          value: _scheduledTime != null
                              ? _scheduledTime!.format(context)
                              : 'Select',
                          icon: Icons.access_time_rounded,
                          onTap: () => _selectTime(context),
                          isSelected: _scheduledTime != null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Location Card (Optional)
              _buildCard(
                title: 'Location (Optional)',
                icon: Icons.location_on_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _latitudeController,
                          label: 'Latitude',
                          hint: 'e.g., 48.8584',
                          icon: Icons.explore_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.space16),
                      Expanded(
                        child: _buildTextField(
                          controller: _longitudeController,
                          label: 'Longitude',
                          hint: 'e.g., 2.2945',
                          icon: Icons.explore_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space12),
                  LocationPickerButton(
                    latitudeController: _latitudeController,
                    longitudeController: _longitudeController,
                    isEnabled: !_isLoading,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space32),

              // Submit Button
              AnimatedButton(
                text: widget.activity == null ? 'Add Activity' : 'Update Activity',
                onPressed: _isLoading ? null : _handleSubmit,
                isLoading: _isLoading,
                icon: widget.activity == null
                    ? Icons.add_rounded
                    : Icons.save_rounded,
                height: AppSizes.buttonHeightLg,
              ),
              const SizedBox(height: AppSizes.space24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.space20),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        boxShadow: AppSizes.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lemonLight,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Icon(icon, color: AppColors.sunnyYellow, size: 20),
              ),
              const SizedBox(width: AppSizes.space12),
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_isLoading,
      keyboardType: keyboardType,
      style: AppTypography.bodyLarge.copyWith(
        color: AppColors.charcoal,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.slate,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.mutedGray,
        ),
        prefixIcon: Icon(icon, color: AppColors.slate),
        filled: true,
        fillColor: AppColors.warmGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.sunnyYellow,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDateButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: AppColors.warmGray,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.sunnyYellow : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: AppSizes.space4),
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppColors.sunnyYellow : AppColors.slate,
                ),
                const SizedBox(width: AppSizes.space8),
                Expanded(
                  child: Text(
                    value,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isSelected ? AppColors.charcoal : AppColors.mutedGray,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: AppSizes.space8,
      runSpacing: AppSizes.space8,
      children: ActivityCategory.values.map((category) {
        final isSelected = _category == category;
        final color = _getCategoryColor(category);

        return GestureDetector(
          onTap: _isLoading
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  setState(() => _category = category);
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              vertical: AppSizes.space12,
              horizontal: AppSizes.space16,
            ),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : AppColors.warmGray,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: AppSizes.space8),
                Text(
                  category.displayName,
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected ? color : AppColors.slate,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.food:
        return AppColors.coralBurst;
      case ActivityCategory.travel:
        return AppColors.skyBlue;
      case ActivityCategory.stay:
        return AppColors.lavenderDream;
      case ActivityCategory.explore:
        return AppColors.oceanTeal;
    }
  }
}
