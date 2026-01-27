import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';
import '../../core/utils/file_url_helper.dart';

/// Mode for cover image selection
enum CoverImageMode {
  url,
  upload,
}

/// Result from the cover image picker
class CoverImageResult {
  /// URL string (for URL mode or after upload)
  final String? url;

  /// Local file (for upload mode before upload)
  final File? localFile;

  /// Whether this needs uploading (true if localFile is set)
  bool get needsUpload => localFile != null;

  const CoverImageResult({
    this.url,
    this.localFile,
  });

  /// Create result from URL
  factory CoverImageResult.fromUrl(String url) {
    return CoverImageResult(url: url.trim().isEmpty ? null : url.trim());
  }

  /// Create result from local file
  factory CoverImageResult.fromFile(File file) {
    return CoverImageResult(localFile: file);
  }

  /// Empty result
  static const CoverImageResult empty = CoverImageResult();

  /// Check if result has any value
  bool get hasValue => url != null || localFile != null;

  @override
  String toString() {
    if (localFile != null) return 'CoverImageResult(file: ${localFile!.path})';
    if (url != null) return 'CoverImageResult(url: $url)';
    return 'CoverImageResult(empty)';
  }
}

/// A widget for picking a cover image either from URL or by uploading from device
class CoverImagePicker extends StatefulWidget {
  /// Initial URL value (for editing existing trips)
  final String? initialUrl;

  /// Callback when the value changes
  final ValueChanged<CoverImageResult> onChanged;

  /// Whether the picker is enabled
  final bool enabled;

  const CoverImagePicker({
    super.key,
    this.initialUrl,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<CoverImagePicker> createState() => _CoverImagePickerState();
}

class _CoverImagePickerState extends State<CoverImagePicker> {
  late CoverImageMode _mode;
  late TextEditingController _urlController;
  File? _selectedFile;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    // Default to URL mode if there's an initial URL, otherwise upload mode
    _mode = (widget.initialUrl?.isNotEmpty ?? false)
        ? CoverImageMode.url
        : CoverImageMode.upload;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _switchMode(CoverImageMode newMode) {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = newMode;
      // Clear the other mode's value when switching
      if (newMode == CoverImageMode.url) {
        _selectedFile = null;
        widget.onChanged(CoverImageResult.fromUrl(_urlController.text));
      } else {
        _urlController.clear();
        widget.onChanged(
            _selectedFile != null ? CoverImageResult.fromFile(_selectedFile!) : CoverImageResult.empty);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!widget.enabled) return;

    try {
      HapticFeedback.lightImpact();
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        HapticFeedback.mediumImpact();
        setState(() {
          _selectedFile = File(pickedFile.path);
        });
        widget.onChanged(CoverImageResult.fromFile(_selectedFile!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearSelection() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFile = null;
      _urlController.clear();
    });
    widget.onChanged(CoverImageResult.empty);
  }

  void _onUrlChanged(String value) {
    widget.onChanged(CoverImageResult.fromUrl(value));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode toggle buttons
        _buildModeToggle(),
        const SizedBox(height: AppSizes.space16),

        // Image preview
        _buildImagePreview(),
        const SizedBox(height: AppSizes.space12),

        // Input area based on mode
        if (_mode == CoverImageMode.url)
          _buildUrlInput()
        else
          _buildUploadButtons(),
      ],
    );
  }

  Widget _buildModeToggle() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Upload',
              icon: Icons.upload_rounded,
              isSelected: _mode == CoverImageMode.upload,
              onTap: () => _switchMode(CoverImageMode.upload),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              label: 'URL',
              icon: Icons.link_rounded,
              isSelected: _mode == CoverImageMode.url,
              onTap: () => _switchMode(CoverImageMode.url),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.space8,
          horizontal: AppSizes.space12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          boxShadow: isSelected ? AppSizes.softShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final hasImage = _selectedFile != null ||
        (_urlController.text.trim().isNotEmpty && _mode == CoverImageMode.url);
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 180,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: hasImage ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.15),
          width: hasImage ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_selectedFile != null)
            // Local file preview
            Image.file(
              _selectedFile!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildPlaceholder(),
            )
          else if (_urlController.text.trim().isNotEmpty &&
              _mode == CoverImageMode.url)
            // URL preview
            CachedNetworkImage(
              imageUrl: FileUrlHelper.getAuthenticatedUrl(_urlController.text.trim()),
              fit: BoxFit.cover,
              placeholder: (_, _) => _buildLoadingPlaceholder(),
              errorWidget: (_, _, _) => _buildErrorPlaceholder(),
            )
          else
            // Placeholder
            _buildPlaceholder(),

          // Clear button overlay
          if (hasImage && widget.enabled)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _clearSelection,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    final hintColor = Theme.of(context).hintColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: hintColor,
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            _mode == CoverImageMode.upload
                ? 'Select an image to upload'
                : 'Enter an image URL',
            style: AppTypography.bodySmall.copyWith(
              color: hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.sunnyYellow),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: AppColors.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSizes.space8),
          Text(
            'Invalid image URL',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TextFormField(
      controller: _urlController,
      enabled: widget.enabled,
      onChanged: _onUrlChanged,
      style: AppTypography.bodyLarge.copyWith(
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: 'Image URL',
        hintText: 'https://images.unsplash.com/...',
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: theme.hintColor,
        ),
        prefixIcon: Icon(Icons.link_rounded, color: colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildSourceButton(
            label: 'Camera',
            icon: Icons.camera_alt_rounded,
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
        const SizedBox(width: AppSizes.space12),
        Expanded(
          child: _buildSourceButton(
            label: 'Gallery',
            icon: Icons.photo_library_rounded,
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.space12,
          horizontal: AppSizes.space16,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: widget.enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: widget.enabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
