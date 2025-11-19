import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/utils/validators.dart';
import '../../data/models/trip_model.dart';
import '../providers/trips_provider.dart';

class TripFormScreen extends ConsumerStatefulWidget {
  final TripModel? trip; // null for create, non-null for edit

  const TripFormScreen({
    super.key,
    this.trip,
  });

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _coverImageUrlController = TextEditingController();
  final _tagController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TripStatus _status = TripStatus.planned;
  List<String> _tags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.trip != null) {
      _initializeWithTrip(widget.trip!);
    }
  }

  void _initializeWithTrip(TripModel trip) {
    _titleController.text = trip.title;
    _descriptionController.text = trip.description ?? '';
    _coverImageUrlController.text = trip.coverImageUrl ?? '';
    _startDate = DateTime.parse(trip.startDate);
    _endDate = DateTime.parse(trip.endDate);
    _status = TripStatus.values.firstWhere(
      (s) => s.name == trip.status,
      orElse: () => TripStatus.planned,
    );
    _tags = trip.tags ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _coverImageUrlController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sunsetGold,
              onPrimary: AppColors.midnightBlue,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Auto-adjust end date if it's before start date
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end dates'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = TripRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        coverImageUrl: _coverImageUrlController.text.trim().isEmpty
            ? null
            : _coverImageUrlController.text.trim(),
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        status: _status.name,
        tags: _tags.isEmpty ? null : _tags,
      );

      if (widget.trip == null) {
        // Create new trip
        await ref.read(tripsProvider.notifier).createTrip(request);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Update existing trip
        await ref.read(tripsProvider.notifier).updateTrip(
          widget.trip!.id,
          request.toJson(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
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
      appBar: AppBar(
        title: Text(
          widget.trip == null ? 'Create Trip' : 'Edit Trip',
          style: AppTypography.headlineSmall,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.frostedWhite,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title Field
                Text(
                  'Trip Title',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Paris Adventure',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) =>
                      Validators.required(value, fieldName: 'Title'),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: AppSizes.space24),

                // Description Field
                Text(
                  'Description (Optional)',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Tell us about your trip...',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: AppSizes.space24),

                // Cover Image URL
                Text(
                  'Cover Image URL (Optional)',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                TextFormField(
                  controller: _coverImageUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://images.unsplash.com/...',
                    prefixIcon: Icon(Icons.image),
                  ),
                  validator: Validators.url,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: AppSizes.space24),

                // Date Selection
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Date',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSizes.space8),
                          OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _selectDate(context, true),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _startDate == null
                                  ? 'Select Date'
                                  : DateFormat('MMM dd, yyyy')
                                      .format(_startDate!),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Date',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSizes.space8),
                          OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _selectDate(context, false),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _endDate == null
                                  ? 'Select Date'
                                  : DateFormat('MMM dd, yyyy')
                                      .format(_endDate!),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.space24),

                // Status Selection
                Text(
                  'Trip Status',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                SegmentedButton<TripStatus>(
                  segments: TripStatus.values
                      .map((status) => ButtonSegment<TripStatus>(
                            value: status,
                            label: Text(status.displayName),
                          ))
                      .toList(),
                  selected: {_status},
                  onSelectionChanged: _isLoading
                      ? null
                      : (Set<TripStatus> selected) {
                          setState(() {
                            _status = selected.first;
                          });
                        },
                ),
                const SizedBox(height: AppSizes.space24),

                // Tags
                Text(
                  'Tags (Optional)',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.space8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          hintText: 'Add a tag',
                          prefixIcon: Icon(Icons.label),
                        ),
                        onFieldSubmitted: (_) => _addTag(),
                        enabled: !_isLoading,
                      ),
                    ),
                    const SizedBox(width: AppSizes.space8),
                    IconButton(
                      onPressed: _isLoading ? null : _addTag,
                      icon: const Icon(Icons.add_circle),
                      color: AppColors.sunsetGold,
                      iconSize: 32,
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.space12),
                  Wrap(
                    spacing: AppSizes.space8,
                    runSpacing: AppSizes.space8,
                    children: _tags.map((tag) {
                      return CustomChip(
                        label: tag,
                        onDelete: _isLoading ? null : () => _removeTag(tag),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSizes.space40),

                // Submit Button
                CustomButton(
                  text: widget.trip == null ? 'Create Trip' : 'Update Trip',
                  onPressed: _isLoading ? null : _handleSubmit,
                  isLoading: _isLoading,
                  icon: widget.trip == null ? Icons.add : Icons.save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
