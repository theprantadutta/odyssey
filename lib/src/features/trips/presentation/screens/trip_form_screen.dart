import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../common/constants/currencies.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/widgets/cover_image_picker.dart';
import '../../../../common/animations/animated_widgets/animated_button.dart';
import '../../../../common/utils/validators.dart';
import '../../../../core/services/file_upload_service.dart';
import '../../data/models/trip_model.dart';
import '../providers/trips_provider.dart';

class TripFormScreen extends ConsumerStatefulWidget {
  final TripModel? trip;

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
  final _tagController = TextEditingController();
  final _budgetController = TextEditingController();
  final _fileUploadService = FileUploadService();

  DateTime? _startDate;
  DateTime? _endDate;
  TripStatus _status = TripStatus.planned;
  List<String> _tags = [];
  bool _isLoading = false;
  CoverImageResult _coverImageResult = CoverImageResult.empty;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String _displayCurrency = 'USD';

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
    if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty) {
      _coverImageResult = CoverImageResult.fromUrl(trip.coverImageUrl!);
    }
    _startDate = DateTime.parse(trip.startDate);
    _endDate = DateTime.parse(trip.endDate);
    _status = TripStatus.values.firstWhere(
      (s) => s.name == trip.status,
      orElse: () => TripStatus.planned,
    );
    _tags = trip.tags ?? [];
    if (trip.budget != null) {
      _budgetController.text = trip.budget!.toStringAsFixed(2);
    }
    _displayCurrency = trip.displayCurrency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    HapticFeedback.selectionClick();
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
              primary: AppColors.sunnyYellow,
              onPrimary: AppColors.charcoal,
              onSurface: AppColors.charcoal,
              surface: AppColors.snowWhite,
            ), dialogTheme: DialogThemeData(backgroundColor: AppColors.snowWhite),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.lightImpact();
      setState(() {
        if (isStartDate) {
          _startDate = picked;
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
      HapticFeedback.lightImpact();
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_startDate == null || _endDate == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: AppSizes.space12),
              Text('Please select start and end dates'),
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
      // Handle cover image upload if needed
      String? coverImageUrl = _coverImageResult.url;

      if (_coverImageResult.needsUpload) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        try {
          final uploadResult = await _fileUploadService.uploadCoverImage(
            file: _coverImageResult.localFile!,
            onProgress: (sent, total) {
              if (mounted) {
                setState(() {
                  _uploadProgress = sent / total;
                });
              }
            },
          );
          coverImageUrl = uploadResult.url;
        } finally {
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
          }
        }
      }

      final budgetText = _budgetController.text.trim();
      final budget = budgetText.isEmpty ? null : double.tryParse(budgetText);

      final request = TripRequest(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        coverImageUrl: coverImageUrl,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        status: _status.name,
        tags: _tags.isEmpty ? null : _tags,
        budget: budget,
        displayCurrency: _displayCurrency,
      );

      if (widget.trip == null) {
        await ref.read(tripsProvider.notifier).createTrip(request);
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: AppSizes.space12),
                  Text('Trip created successfully!'),
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
        await ref.read(tripsProvider.notifier).updateTrip(
              widget.trip!.id,
              request.toJson(),
            );
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: AppSizes.space12),
                  Text('Trip updated successfully!'),
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
          widget.trip == null ? 'Create Trip' : 'Edit Trip',
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
                title: 'Basic Info',
                icon: Icons.info_outline_rounded,
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: 'Trip Title',
                    hint: 'e.g., Paris Adventure',
                    icon: Icons.title_rounded,
                    validator: (value) =>
                        Validators.required(value, fieldName: 'Title'),
                  ),
                  const SizedBox(height: AppSizes.space16),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description (Optional)',
                    hint: 'Tell us about your trip...',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Cover Image Card
              _buildCard(
                title: 'Cover Image',
                icon: Icons.image_rounded,
                children: [
                  CoverImagePicker(
                    initialUrl: widget.trip?.coverImageUrl,
                    enabled: !_isLoading,
                    onChanged: (result) {
                      setState(() {
                        _coverImageResult = result;
                      });
                    },
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: AppSizes.space12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppColors.warmGray,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.sunnyYellow),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: AppSizes.space8),
                    Text(
                      'Uploading... ${(_uploadProgress * 100).toInt()}%',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slate,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Dates Card
              _buildCard(
                title: 'Trip Dates',
                icon: Icons.calendar_today_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateButton(
                          label: 'Start Date',
                          date: _startDate,
                          onTap: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: AppSizes.space16),
                      Expanded(
                        child: _buildDateButton(
                          label: 'End Date',
                          date: _endDate,
                          onTap: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Status Card
              _buildCard(
                title: 'Trip Status',
                icon: Icons.flag_rounded,
                children: [
                  _buildStatusSelector(),
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Tags Card
              _buildCard(
                title: 'Tags',
                icon: Icons.label_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _tagController,
                          label: 'Add a tag',
                          hint: 'adventure, family, beach...',
                          icon: Icons.tag_rounded,
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                      const SizedBox(width: AppSizes.space8),
                      GestureDetector(
                        onTap: _isLoading ? null : _addTag,
                        child: Container(
                          padding: const EdgeInsets.all(AppSizes.space12),
                          decoration: BoxDecoration(
                            color: AppColors.sunnyYellow,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: AppColors.charcoal,
                          ),
                        ),
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
                          color: AppColors.oceanTeal,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.space16),

              // Budget Card
              _buildCard(
                title: 'Budget (Optional)',
                icon: Icons.account_balance_wallet_rounded,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Currency Dropdown
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.warmGray,
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _displayCurrency,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.space12,
                            ),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                            items: commonCurrencies.map((c) {
                              return DropdownMenuItem(
                                value: c.code,
                                child: Text(
                                  '${c.symbol} ${c.code}',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.charcoal,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _displayCurrency = value);
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.space12),
                      // Budget Amount
                      Expanded(
                        child: TextFormField(
                          controller: _budgetController,
                          enabled: !_isLoading,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: AppTypography.bodyLarge.copyWith(
                              color: AppColors.mutedGray,
                            ),
                            filled: true,
                            fillColor: AppColors.warmGray,
                            border: OutlineInputBorder(
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
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.space8),
                  Text(
                    'Set a budget to track your expenses. All expenses will be converted to this currency.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space32),

              // Submit Button
              AnimatedButton(
                text: _isUploading
                    ? 'Uploading Image...'
                    : (widget.trip == null ? 'Create Trip' : 'Update Trip'),
                onPressed: _isLoading ? null : _handleSubmit,
                isLoading: _isLoading,
                icon: _isUploading
                    ? Icons.cloud_upload_rounded
                    : (widget.trip == null
                        ? Icons.add_rounded
                        : Icons.save_rounded),
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
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_isLoading,
      onFieldSubmitted: onSubmitted,
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
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: AppColors.warmGray,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: date != null ? AppColors.sunnyYellow : Colors.transparent,
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
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: date != null ? AppColors.sunnyYellow : AppColors.slate,
                ),
                const SizedBox(width: AppSizes.space8),
                Flexible(
                  child: Text(
                    date == null
                        ? 'Select'
                        : DateFormat('MMM dd, yyyy').format(date),
                    style: AppTypography.bodyMedium.copyWith(
                      color:
                          date != null ? AppColors.charcoal : AppColors.mutedGray,
                      fontWeight: date != null ? FontWeight.w500 : FontWeight.w400,
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

  Widget _buildStatusSelector() {
    return Row(
      children: TripStatus.values.map((status) {
        final isSelected = _status == status;
        Color bgColor;
        Color textColor;
        IconData icon;

        switch (status) {
          case TripStatus.planned:
            bgColor = AppColors.statusPlannedBg;
            textColor = AppColors.goldenGlow;
            icon = Icons.schedule_rounded;
            break;
          case TripStatus.ongoing:
            bgColor = AppColors.statusOngoingBg;
            textColor = AppColors.oceanTeal;
            icon = Icons.flight_takeoff_rounded;
            break;
          case TripStatus.completed:
            bgColor = AppColors.statusCompletedBg;
            textColor = AppColors.success;
            icon = Icons.check_circle_rounded;
            break;
        }

        return Expanded(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    setState(() => _status = status);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                right: status != TripStatus.completed ? AppSizes.space8 : 0,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.space12,
                horizontal: AppSizes.space8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? bgColor : AppColors.warmGray,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: isSelected ? textColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    icon,
                    color: isSelected ? textColor : AppColors.slate,
                    size: 24,
                  ),
                  const SizedBox(height: AppSizes.space4),
                  Text(
                    status.displayName,
                    style: AppTypography.caption.copyWith(
                      color: isSelected ? textColor : AppColors.slate,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
