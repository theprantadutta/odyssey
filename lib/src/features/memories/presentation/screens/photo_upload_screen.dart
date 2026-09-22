import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/location_picker_button.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../subscription/presentation/providers/feature_access_provider.dart';
import '../../../subscription/presentation/screens/paywall_screen.dart';
import '../../../subscription/presentation/utils/limit_checker.dart';
import '../../data/models/upload_outcome.dart';
import '../../data/repositories/memory_repository.dart';
import '../providers/memories_provider.dart';

/// Maximum file size for photos (10MB).
const int _maxPhotoSizeBytes = 10 * 1024 * 1024;

/// Maximum file size for videos (100MB).
const int _maxVideoSizeBytes = 100 * 1024 * 1024;

/// How many files one memory may carry.
const int _maxMediaFiles = 10;

/// One picked photo or video, before it is uploaded.
class _SelectedMedia {
  const _SelectedMedia({
    required this.file,
    required this.isVideo,
    required this.fileName,
  });

  final File file;
  final bool isVideo;
  final String fileName;
}

/// Add a memory: photos or a video, a caption, where and when.
class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({
    super.key,
    required this.tripId,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String tripId;
  final double? initialLatitude;
  final double? initialLongitude;

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
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _selectedMedia.isNotEmpty || _captionController.text.trim().isNotEmpty;

  String get _submitLabel {
    if (_selectedMedia.isEmpty && _captionController.text.trim().isEmpty) {
      return 'Add a photo or a note';
    }
    if (_selectedMedia.isEmpty) return 'Save the note';
    return _selectedMedia.length == 1
        ? 'Save the memory'
        : 'Save ${_selectedMedia.length} files';
  }

  Future<void> _pickFrom(ImageSource source, {required bool isVideo}) async {
    try {
      if (isVideo) {
        final hasAccess = ref.read(
          featureAccessProvider(PremiumFeature.videoUpload),
        );
        if (!hasAccess) {
          if (mounted) {
            PaywallUtils.showPaywall(
              context,
              featureName: 'Video Uploads',
              customDescription:
                  'Keep the moving ones too, not just the stills.',
              featureIcon: Icons.videocam,
              unlockableFeature: PremiumFeature.videoUpload,
            );
          }
          return;
        }

        final picked = await _imagePicker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5),
        );
        if (picked == null) return;

        final file = File(picked.path);
        if (await file.length() > _maxVideoSizeBytes) {
          if (mounted) {
            showOdysseyMessage(context, 'That video is over the 100MB limit.');
          }
          return;
        }

        setState(() {
          _selectedMedia.add(
            _SelectedMedia(file: file, isVideo: true, fileName: picked.name),
          );
        });
        return;
      }

      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      if (await file.length() > _maxPhotoSizeBytes) {
        if (mounted) {
          showOdysseyMessage(context, 'That photo is over the 10MB limit.');
        }
        return;
      }

      setState(() {
        _selectedMedia.add(
          _SelectedMedia(file: file, isVideo: false, fileName: picked.name),
        );
      });
    } catch (e) {
      if (mounted) showOdysseyError(context, 'Could not open that.', error: e);
    }
  }

  Future<void> _addMedia() async {
    if (_selectedMedia.length >= _maxMediaFiles) {
      showOdysseyMessage(context, 'That is $_maxMediaFiles files — the limit.');
      return;
    }

    final choice = await showOdysseyPicker<String>(
      context: context,
      title: 'Add',
      options: const ['Take a photo', 'Photo library', 'Record a video', 'Video library'],
      labelOf: (value) => value,
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'Take a photo':
        await _pickFrom(ImageSource.camera, isVideo: false);
      case 'Photo library':
        await _pickFrom(ImageSource.gallery, isVideo: false);
      case 'Record a video':
        await _pickFrom(ImageSource.camera, isVideo: true);
      case 'Video library':
        await _pickFrom(ImageSource.gallery, isVideo: true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _takenAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _takenAt = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _takenAtTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _takenAtTime = picked);
  }

  Future<void> _handleUpload() async {
    final currentCount =
        ref.read(tripMemoriesProvider(widget.tripId)).memories.length;
    final canCreate = await LimitChecker.canCreateMemory(
      context,
      ref,
      currentCount: currentCount,
    );
    if (!canCreate || !mounted) return;

    if (!_formKey.currentState!.validate()) return;
    if (!_hasContent) {
      showOdysseyMessage(context, 'Add a photo or write something.');
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      final mediaFiles = _selectedMedia.isEmpty
          ? null
          : _selectedMedia
                .map(
                  (m) => SelectedMediaFile(
                    file: m.file,
                    isVideo: m.isVideo,
                    fileName: m.fileName,
                  ),
                )
                .toList();

      double? latitude;
      double? longitude;
      if (_latitudeController.text.isNotEmpty &&
          _longitudeController.text.isNotEmpty) {
        latitude = double.tryParse(_latitudeController.text);
        longitude = double.tryParse(_longitudeController.text);
      }

      DateTime? takenAt;
      if (_takenAt != null) {
        takenAt = _takenAtTime == null
            ? _takenAt
            : DateTime(
                _takenAt!.year,
                _takenAt!.month,
                _takenAt!.day,
                _takenAtTime!.hour,
                _takenAtTime!.minute,
              );
      }

      final caption = _captionController.text.trim();
      final location = _locationController.text.trim();

      await ref
          .read(tripMemoriesProvider(widget.tripId).notifier)
          .uploadMemory(
            mediaFiles: mediaFiles,
            location: location.isEmpty ? null : location,
            latitude: latitude,
            longitude: longitude,
            caption: caption.isEmpty ? null : caption,
            takenAt: takenAt,
          );

      if (!mounted) return;
      showOdysseyMessage(context, 'Saved to the journal.');
      Navigator.of(context).pop();
    } on UploadFailure catch (failure) {
      // The draft is deliberately left intact — the caption, the location and
      // the selected files all stay on screen. Losing a considered caption
      // because a network hiccup interrupted the upload is worse than the
      // hiccup.
      if (mounted) {
        showOdysseyMessage(
          context,
          failure.isRetryable
              ? '${failure.message} You can try again.'
              : failure.message,
        );
      }
    } catch (e) {
      if (mounted) showOdysseyError(context, 'That did not upload.', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tripMemoriesProvider(widget.tripId));

    return OdysseyFormScreen(
      formKey: _formKey,
      onChanged: () => setState(() {}),
      title: 'New memory',
      subtitle: 'Photos, a video, or just a line worth keeping.',
      submitLabel: _submitLabel,
      isLoading: state.isUploading,
      onSubmit: _hasContent && !state.isUploading ? _handleUpload : null,
      children: [
        _MediaGrid(
          media: _selectedMedia,
          onAdd: _addMedia,
          onRemove: (index) => setState(() => _selectedMedia.removeAt(index)),
        ),
        const SizedBox(height: AppSizes.space18),

        FieldCard(
          label: 'Caption',
          controller: _captionController,
          hint: 'What was happening',
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSizes.space12),

        FieldCard(
          label: 'Place',
          controller: _locationController,
          hint: 'Optional',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: AppSizes.space12),

        Row(
          children: [
            Expanded(
              child: ValueCard(
                label: 'Taken on',
                value: _takenAt == null
                    ? null
                    : TripFormat.shortDate(_takenAt),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: AppSizes.space10),
            Expanded(
              child: ValueCard(
                label: 'At',
                value: _takenAtTime?.format(context),
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space20),

        FormGroup(
          label: 'Where on the map',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocationPickerButton(
                latitudeController: _latitudeController,
                longitudeController: _longitudeController,
                isEnabled: !state.isUploading,
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

/// The picked files, as a two-up grid ending in a dashed add tile.
class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.media,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_SelectedMedia> media;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    if (media.isEmpty) {
      return DashedBox(
        radius: AppSizes.radiusTile,
        height: 150,
        onTap: onAdd,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '+',
              style: AppTypography.glyph.copyWith(fontSize: 26, color: t.ink2),
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Add photos or a video',
              style: AppTypography.legend.copyWith(color: t.ink3),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSizes.space10,
        mainAxisSpacing: AppSizes.space10,
        mainAxisExtent: 130,
      ),
      itemCount: media.length + 1,
      itemBuilder: (context, index) {
        if (index == media.length) {
          return DashedBox(
            radius: AppSizes.radiusTile,
            onTap: onAdd,
            child: Text(
              '+',
              style: AppTypography.glyph.copyWith(fontSize: 22, color: t.ink2),
            ),
          );
        }

        final item = media[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(item.file, fit: BoxFit.cover),
              if (item.isVideo)
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.photoScrim),
                ),
              if (item.isVideo)
                const Positioned(
                  left: AppSizes.space10,
                  bottom: AppSizes.space10,
                  child: PhotoTag('video', compact: true),
                ),
              Positioned(
                right: AppSizes.space8,
                top: AppSizes.space8,
                child: CircleButton(
                  glyph: '✕',
                  size: AppSizes.circleSm,
                  style: CircleStyle.glass,
                  onPressed: () => onRemove(index),
                  semanticLabel: 'Remove ${item.fileName}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
