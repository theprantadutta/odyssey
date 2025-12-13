import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../providers/memories_provider.dart';

/// Screen for uploading a new photo memory
class PhotoUploadScreen extends ConsumerStatefulWidget {
  final String tripId;
  final double? initialLatitude;
  final double? initialLongitude;

  const PhotoUploadScreen({
    super.key,
    required this.tripId,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  ConsumerState<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _imagePicker = ImagePicker();

  File? _selectedImage;
  DateTime? _takenAt;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null) {
      _latitudeController.text = widget.initialLatitude.toString();
    }
    if (widget.initialLongitude != null) {
      _longitudeController.text = widget.initialLongitude.toString();
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memoriesState = ref.watch(tripMemoriesProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.snowWhite,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image picker section
                    _buildImagePicker(),
                    const SizedBox(height: AppSizes.space24),

                    // Caption field
                    _buildCaptionField(),
                    const SizedBox(height: AppSizes.space16),

                    // Location section
                    _buildLocationSection(),
                    const SizedBox(height: AppSizes.space16),

                    // Date taken
                    _buildDateField(),
                  ],
                ),
              ),
            ),

            // Upload button
            _buildUploadButton(memoriesState),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.snowWhite,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.charcoal),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      title: Text(
        'Add Memory',
        style: AppTypography.headlineSmall.copyWith(
          color: AppColors.charcoal,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.warmGray,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(
                color: _selectedImage == null
                    ? AppColors.mutedGray
                    : AppColors.sunnyYellow,
                width: 2,
              ),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg - 2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: AppSizes.space8,
                          right: AppSizes.space8,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedImage = null);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(AppSizes.space8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusFull),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSizes.space16),
                        decoration: BoxDecoration(
                          color: AppColors.lemonLight,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Icon(
                          Icons.add_a_photo_rounded,
                          size: 32,
                          color: AppColors.goldenGlow,
                        ),
                      ),
                      const SizedBox(height: AppSizes.space12),
                      Text(
                        'Tap to add a photo',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.slate,
                        ),
                      ),
                      const SizedBox(height: AppSizes.space4),
                      Text(
                        'Camera or Gallery',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.mutedGray,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Caption (Optional)',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _captionController,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Write a caption for your memory...',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.mutedGray,
            ),
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
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.charcoal,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Location',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space8,
                vertical: AppSizes.space4,
              ),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Text(
                'Required',
                style: AppTypography.caption.copyWith(
                  color: AppColors.goldenGlow,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _latitudeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.slate,
                  ),
                  hintText: 'e.g., 23.8103',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.mutedGray,
                  ),
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
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(AppSizes.space12),
                ),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.charcoal,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final lat = double.tryParse(value);
                  if (lat == null || lat < -90 || lat > 90) {
                    return 'Invalid latitude';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            Expanded(
              child: TextFormField(
                controller: _longitudeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.slate,
                  ),
                  hintText: 'e.g., 90.4125',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.mutedGray,
                  ),
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
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(AppSizes.space12),
                ),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.charcoal,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final lng = double.tryParse(value);
                  if (lng == null || lng < -180 || lng > 180) {
                    return 'Invalid longitude';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        Text(
          'Enter the coordinates where this photo was taken',
          style: AppTypography.caption.copyWith(
            color: AppColors.mutedGray,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Taken (Optional)',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.space16),
            decoration: BoxDecoration(
              color: AppColors.warmGray,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: _takenAt != null
                      ? AppColors.goldenGlow
                      : AppColors.mutedGray,
                  size: 20,
                ),
                const SizedBox(width: AppSizes.space12),
                Text(
                  _takenAt != null
                      ? _formatDate(_takenAt!)
                      : 'Select date',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _takenAt != null
                        ? AppColors.charcoal
                        : AppColors.mutedGray,
                  ),
                ),
                const Spacer(),
                if (_takenAt != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _takenAt = null);
                    },
                    child: Icon(
                      Icons.close_rounded,
                      color: AppColors.mutedGray,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton(MemoriesState memoriesState) {
    final isUploading = memoriesState.isUploading;
    final progress = memoriesState.uploadProgress;

    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: AppColors.snowWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.warmGray,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.sunnyYellow),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: AppSizes.space8),
              Text(
                'Uploading... ${(progress * 100).toInt()}%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: AppSizes.space12),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isUploading || _selectedImage == null
                    ? null
                    : _handleUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunnyYellow,
                  foregroundColor: AppColors.charcoal,
                  disabledBackgroundColor: AppColors.warmGray,
                  disabledForegroundColor: AppColors.mutedGray,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
                child: isUploading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.charcoal,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_upload_rounded),
                          const SizedBox(width: AppSizes.space8),
                          Text(
                            'Upload Memory',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.charcoal,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.snowWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedGray,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
              const SizedBox(height: AppSizes.space24),
              Text(
                'Choose Photo Source',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: AppSizes.space24),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.space16),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space24),
        decoration: BoxDecoration(
          color: AppColors.warmGray,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space16),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppColors.goldenGlow,
              ),
            ),
            const SizedBox(height: AppSizes.space12),
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _takenAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.sunnyYellow,
              onPrimary: AppColors.charcoal,
              surface: AppColors.snowWhite,
              onSurface: AppColors.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => _takenAt = date);
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: AppSizes.space12),
              Text('Please select a photo'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      await ref.read(tripMemoriesProvider(widget.tripId).notifier).uploadMemory(
            photoFile: _selectedImage!,
            latitude: double.parse(_latitudeController.text),
            longitude: double.parse(_longitudeController.text),
            caption: _captionController.text.isNotEmpty
                ? _captionController.text
                : null,
            takenAt: _takenAt,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: AppSizes.space12),
                Text('Memory uploaded successfully!'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    }
  }
}
