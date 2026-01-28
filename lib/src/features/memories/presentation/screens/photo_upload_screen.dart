import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/location_picker_button.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../data/repositories/memory_repository.dart';
import '../providers/memories_provider.dart';

/// Maximum file size for photos (10MB)
const int _maxPhotoSizeBytes = 10 * 1024 * 1024;

/// Maximum file size for videos (100MB)
const int _maxVideoSizeBytes = 100 * 1024 * 1024;

/// Maximum number of media files per memory
const int _maxMediaFiles = 10;

/// Represents a selected media item (photo or video)
class _SelectedMedia {
  final File file;
  final bool isVideo;
  final String fileName;

  _SelectedMedia({
    required this.file,
    required this.isVideo,
    required this.fileName,
  });
}

/// Screen for uploading a new memory with photos/videos
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
  final _locationController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _imagePicker = ImagePicker();

  final List<_SelectedMedia> _selectedMedia = [];
  DateTime? _takenAt;
  TimeOfDay? _takenAtTime;
  bool _showGpsFields = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null) {
      _latitudeController.text = widget.initialLatitude.toString();
      _showGpsFields = true;
    }
    if (widget.initialLongitude != null) {
      _longitudeController.text = widget.initialLongitude.toString();
      _showGpsFields = true;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final memoriesState = ref.watch(tripMemoriesProvider(widget.tripId));

    return Scaffold(
      backgroundColor: colorScheme.surface,
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
                    // Media picker grid
                    _buildMediaPickerSection(),
                    const SizedBox(height: AppSizes.space24),

                    // Caption field
                    _buildCaptionField(),
                    const SizedBox(height: AppSizes.space16),

                    // Location text field
                    _buildLocationField(),
                    const SizedBox(height: AppSizes.space16),

                    // GPS Coordinates section (collapsible)
                    _buildGpsSection(),
                    const SizedBox(height: AppSizes.space16),

                    // Date & Time taken
                    _buildDateTimeField(),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: colorScheme.onSurface),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
      ),
      title: Text(
        'Add Memory',
        style: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildMediaPickerSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Photos & Videos',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '(Optional)',
              style: AppTypography.caption.copyWith(
                color: theme.hintColor,
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedMedia.length}/$_maxMediaFiles',
              style: AppTypography.caption.copyWith(
                color: _selectedMedia.length >= _maxMediaFiles
                    ? AppColors.error
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        _buildMediaGrid(),
        const SizedBox(height: AppSizes.space8),
        Text(
          'Photos: max 10MB each • Videos: max 100MB each',
          style: AppTypography.caption.copyWith(
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSizes.space8,
        mainAxisSpacing: AppSizes.space8,
      ),
      itemCount: _selectedMedia.length + (_selectedMedia.length < _maxMediaFiles ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _selectedMedia.length) {
          // Add button
          return _buildAddMediaButton();
        }
        return _buildMediaTile(_selectedMedia[index], index);
      },
    );
  }

  Widget _buildAddMediaButton() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: _showMediaSourceDialog,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: theme.hintColor,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space12),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 24,
                color: AppColors.goldenGlow,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Add',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTile(_SelectedMedia media, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image or video placeholder
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: media.isVideo
              ? Container(
                  color: colorScheme.onSurface,
                  child: const Center(
                    child: Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                )
              : Image.file(media.file, fit: BoxFit.cover),
        ),

        // Video indicator
        if (media.isVideo)
          Positioned(
            bottom: AppSizes.space4,
            left: AppSizes.space4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space8,
                vertical: AppSizes.space4,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Video',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Remove button
        Positioned(
          top: AppSizes.space4,
          right: AppSizes.space4,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedMedia.removeAt(index));
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Caption',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '(Optional)',
              style: AppTypography.caption.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _captionController,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Write a caption for your memory...',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: theme.hintColor,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
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
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Location',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '(Optional)',
              style: AppTypography.caption.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _locationController,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'e.g., Eiffel Tower, Paris',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: theme.hintColor,
            ),
            prefixIcon: Icon(
              Icons.location_on_rounded,
              color: theme.hintColor,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
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
            counterText: '',
          ),
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildGpsSection() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GPS header with toggle
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showGpsFields = !_showGpsFields);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space16,
              vertical: AppSizes.space12,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: _showGpsFields
                      ? AppColors.goldenGlow
                      : theme.hintColor,
                  size: 20,
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Text(
                    'GPS Coordinates',
                    style: AppTypography.bodyMedium.copyWith(
                      color: _showGpsFields
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '(Optional)',
                  style: AppTypography.caption.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: AppSizes.space8),
                Icon(
                  _showGpsFields
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: theme.hintColor,
                ),
              ],
            ),
          ),
        ),

        // GPS fields (collapsible)
        if (_showGpsFields) ...[
          const SizedBox(height: AppSizes.space12),
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
                      color: colorScheme.onSurfaceVariant,
                    ),
                    hintText: 'e.g., 23.8103',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: theme.hintColor,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
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
                    color: colorScheme.onSurface,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final lat = double.tryParse(value);
                      if (lat == null || lat < -90 || lat > 90) {
                        return 'Invalid';
                      }
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
                      color: colorScheme.onSurfaceVariant,
                    ),
                    hintText: 'e.g., 90.4125',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: theme.hintColor,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
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
                    color: colorScheme.onSurface,
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final lng = double.tryParse(value);
                      if (lng == null || lng < -180 || lng > 180) {
                        return 'Invalid';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space12),
          LocationPickerButton(
            latitudeController: _latitudeController,
            longitudeController: _longitudeController,
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeField() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Date & Time Taken',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '(Optional)',
              style: AppTypography.caption.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        Row(
          children: [
            // Date picker
            Expanded(
              child: GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.space16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        color: _takenAt != null
                            ? AppColors.goldenGlow
                            : theme.hintColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppSizes.space12),
                      Expanded(
                        child: Text(
                          _takenAt != null
                              ? _formatDate(_takenAt!)
                              : 'Select date',
                          style: AppTypography.bodyMedium.copyWith(
                            color: _takenAt != null
                                ? colorScheme.onSurface
                                : theme.hintColor,
                          ),
                        ),
                      ),
                      if (_takenAt != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _takenAt = null;
                              _takenAtTime = null;
                            });
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: theme.hintColor,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.space12),
            // Time picker
            Expanded(
              child: GestureDetector(
                onTap: _takenAt != null ? _selectTime : null,
                child: Container(
                  padding: const EdgeInsets.all(AppSizes.space16),
                  decoration: BoxDecoration(
                    color: _takenAt != null
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: _takenAtTime != null
                            ? AppColors.goldenGlow
                            : theme.hintColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppSizes.space12),
                      Expanded(
                        child: Text(
                          _takenAtTime != null
                              ? _formatTime(_takenAtTime!)
                              : 'Time',
                          style: AppTypography.bodyMedium.copyWith(
                            color: _takenAtTime != null
                                ? colorScheme.onSurface
                                : theme.hintColor,
                          ),
                        ),
                      ),
                      if (_takenAtTime != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _takenAtTime = null);
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: theme.hintColor,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploadButton(MemoriesState memoriesState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUploading = memoriesState.isUploading;
    final progress = memoriesState.uploadProgress;
    final hasContent = _selectedMedia.isNotEmpty || _captionController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSizes.space16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.sunnyYellow),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: AppSizes.space8),
              Text(
                'Uploading... ${(progress * 100).toInt()}%',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSizes.space12),
            ],
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isUploading || !hasContent ? null : _handleUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunnyYellow,
                  foregroundColor: colorScheme.onSurface,
                  disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: theme.hintColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                ),
                child: isUploading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurface,
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
                              color: colorScheme.onSurface,
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

  void _showMediaSourceDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
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
                  color: theme.hintColor,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
              ),
              const SizedBox(height: AppSizes.space24),
              Text(
                'Add Media',
                style: AppTypography.headlineSmall.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSizes.space24),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      subtitle: 'Photo',
                      onTap: () {
                        Navigator.pop(context);
                        _pickMedia(ImageSource.camera, isVideo: false);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.videocam_rounded,
                      label: 'Camera',
                      subtitle: 'Video',
                      onTap: () {
                        Navigator.pop(context);
                        _pickMedia(ImageSource.camera, isVideo: true);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space12),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      subtitle: 'Photos',
                      onTap: () {
                        Navigator.pop(context);
                        _pickMedia(ImageSource.gallery, isVideo: false);
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.video_library_rounded,
                      label: 'Gallery',
                      subtitle: 'Videos',
                      onTap: () {
                        Navigator.pop(context);
                        _pickMedia(ImageSource.gallery, isVideo: true);
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
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppSizes.space16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.space12),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
              child: Icon(
                icon,
                size: 24,
                color: AppColors.goldenGlow,
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source, {required bool isVideo}) async {
    try {
      // Check if user is trying to pick video and is not premium
      if (isVideo) {
        final isPremium = ref.read(isPremiumProvider);
        if (!isPremium) {
          if (mounted) {
            PaywallUtils.showPaywall(
              context,
              featureName: 'Video Uploads',
              customDescription: 'Upload videos to your memories with Premium',
              featureIcon: Icons.videocam,
            );
          }
          return;
        }

        final pickedFile = await _imagePicker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5),
        );

        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final fileSize = await file.length();

          if (fileSize > _maxVideoSizeBytes) {
            if (mounted) {
              _showError('Video exceeds maximum size of 100MB');
            }
            return;
          }

          setState(() {
            _selectedMedia.add(_SelectedMedia(
              file: file,
              isVideo: true,
              fileName: pickedFile.name,
            ));
          });
        }
      } else {
        final pickedFile = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final fileSize = await file.length();

          if (fileSize > _maxPhotoSizeBytes) {
            if (mounted) {
              _showError('Photo exceeds maximum size of 10MB');
            }
            return;
          }

          setState(() {
            _selectedMedia.add(_SelectedMedia(
              file: file,
              isVideo: false,
              fileName: pickedFile.name,
            ));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to pick media: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: AppSizes.space12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
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

  Future<void> _selectTime() async {
    HapticFeedback.lightImpact();
    final time = await showTimePicker(
      context: context,
      initialTime: _takenAtTime ?? TimeOfDay.now(),
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

    if (time != null) {
      setState(() => _takenAtTime = time);
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;

    final hasMedia = _selectedMedia.isNotEmpty;
    final hasCaption = _captionController.text.isNotEmpty;

    if (!hasMedia && !hasCaption) {
      _showError('Please add media or write a caption');
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      // Build media files list
      List<SelectedMediaFile>? mediaFiles;
      if (_selectedMedia.isNotEmpty) {
        mediaFiles = _selectedMedia
            .map((m) => SelectedMediaFile(
                  file: m.file,
                  isVideo: m.isVideo,
                  fileName: m.fileName,
                ))
            .toList();
      }

      // Parse latitude/longitude if provided
      double? latitude;
      double? longitude;
      if (_latitudeController.text.isNotEmpty &&
          _longitudeController.text.isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text);
        longitude = double.tryParse(_longitudeController.text);
      }

      // Combine date and time
      DateTime? takenAt;
      if (_takenAt != null) {
        if (_takenAtTime != null) {
          takenAt = DateTime(
            _takenAt!.year,
            _takenAt!.month,
            _takenAt!.day,
            _takenAtTime!.hour,
            _takenAtTime!.minute,
          );
        } else {
          takenAt = _takenAt;
        }
      }

      await ref.read(tripMemoriesProvider(widget.tripId).notifier).uploadMemory(
            mediaFiles: mediaFiles,
            location: _locationController.text.isNotEmpty ? _locationController.text : null,
            latitude: latitude,
            longitude: longitude,
            caption: hasCaption ? _captionController.text : null,
            takenAt: takenAt,
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
        _showError('Failed to upload: $e');
      }
    }
  }
}
