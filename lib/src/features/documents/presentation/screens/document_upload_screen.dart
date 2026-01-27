import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:image_picker/image_picker.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/document_repository.dart';
import '../providers/documents_provider.dart';

/// Maximum number of files per document
const int _maxFilesPerDocument = 10;

/// Maximum file size (10MB)
const int _maxFileSizeBytes = 10 * 1024 * 1024;

/// Screen for uploading a document with multiple files
class DocumentUploadScreen extends ConsumerStatefulWidget {
  final String tripId;

  const DocumentUploadScreen({
    super.key,
    required this.tripId,
  });

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  DocumentType _selectedType = DocumentType.other;
  final List<fp.PlatformFile> _selectedFiles = [];
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(theme, colorScheme),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.space20),
                children: [
                  // Name field (MANDATORY)
                  _buildNameField(colorScheme),
                  const SizedBox(height: AppSizes.space20),

                  // File picker
                  _buildFilePicker(theme, colorScheme),
                  const SizedBox(height: AppSizes.space20),

                  // Type selector
                  _buildTypeSelector(colorScheme),
                  const SizedBox(height: AppSizes.space20),

                  // Notes field
                  _buildNotesField(colorScheme),
                ],
              ),
            ),

            // Upload button
            _buildUploadButton(colorScheme),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
        },
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      title: Text(
        'Upload Document',
        style: AppTypography.headlineSmall.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildNameField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Document Name',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSizes.space4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.coralBurst.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                'Required',
                style: AppTypography.caption.copyWith(
                  color: AppColors.coralBurst,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.bodyLarge.copyWith(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g., Flight to Paris, Hotel Booking...',
            hintStyle: AppTypography.bodyLarge.copyWith(color: colorScheme.onSurfaceVariant),
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
              borderSide:
                  const BorderSide(color: AppColors.lavenderDream, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a document name';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFilePicker(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Files',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${_selectedFiles.length}/$_maxFilesPerDocument',
              style: AppTypography.caption.copyWith(
                color: _selectedFiles.length >= _maxFilesPerDocument
                    ? AppColors.error
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),

        // File list
        if (_selectedFiles.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedFiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSizes.space8),
            itemBuilder: (context, index) => _buildFileItem(_selectedFiles[index], index, colorScheme),
          ),
          const SizedBox(height: AppSizes.space12),
        ],

        // Add files button
        if (_selectedFiles.length < _maxFilesPerDocument)
          GestureDetector(
            onTap: _showSourceDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.space16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(
                  color: theme.hintColor,
                  width: 1,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSizes.space8),
                    decoration: BoxDecoration(
                      color: AppColors.lavenderDream.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: AppColors.lavenderDream,
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Text(
                    _selectedFiles.isEmpty ? 'Add Files' : 'Add More Files',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.lavenderDream,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: AppSizes.space8),
        Text(
          'PDF, JPG, PNG, WEBP (max 10MB each, up to 10 files)',
          style: AppTypography.caption.copyWith(
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(fp.PlatformFile file, int index, ColorScheme colorScheme) {
    final isImage = file.extension?.toLowerCase() == 'jpg' ||
        file.extension?.toLowerCase() == 'jpeg' ||
        file.extension?.toLowerCase() == 'png' ||
        file.extension?.toLowerCase() == 'webp';

    return Container(
      padding: const EdgeInsets.all(AppSizes.space12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: AppColors.lavenderDream.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon or thumbnail
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: file.extension?.toLowerCase() == 'pdf'
                  ? AppColors.coralBurst.withValues(alpha: 0.1)
                  : AppColors.skyBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: isImage && file.path != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: Image.file(
                      File(file.path!),
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    file.extension?.toLowerCase() == 'pdf'
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_rounded,
                    size: 22,
                    color: file.extension?.toLowerCase() == 'pdf'
                        ? AppColors.coralBurst
                        : AppColors.skyBlue,
                  ),
          ),

          const SizedBox(width: AppSizes.space12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(file.size),
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Remove button
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedFiles.removeAt(index));
            },
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Document Type',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '(Optional)',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space12),
        Wrap(
          spacing: AppSizes.space8,
          runSpacing: AppSizes.space8,
          children: DocumentType.values.map((type) {
            final isSelected = type == _selectedType;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.space12,
                  vertical: AppSizes.space8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getTypeColor(type)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(
                    color: isSelected
                        ? _getTypeColor(type)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      type.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: AppSizes.space4),
                    Text(
                      type.displayName,
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected ? Colors.white : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotesField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Notes',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '(Optional)',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _notesController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          style: AppTypography.bodyLarge.copyWith(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Add any notes or reminders...',
            hintStyle: AppTypography.bodyLarge.copyWith(color: colorScheme.onSurfaceVariant),
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
              borderSide:
                  const BorderSide(color: AppColors.lavenderDream, width: 2),
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton(ColorScheme colorScheme) {
    final isEnabled = _selectedFiles.isNotEmpty && !_isLoading;

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
            if (_isLoading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.lavenderDream),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: AppSizes.space8),
              Text(
                'Uploading... ${(_uploadProgress * 100).toInt()}%',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSizes.space12),
            ],
            GestureDetector(
              onTap: isEnabled ? _uploadDocument : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppColors.lavenderDream
                      : AppColors.lavenderDream.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: AppColors.lavenderDream.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_upload_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: AppSizes.space8),
                            Text(
                              _selectedFiles.length == 1
                                  ? 'Upload Document'
                                  : 'Upload ${_selectedFiles.length} Files',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(DocumentType type) {
    switch (type) {
      case DocumentType.ticket:
        return AppColors.coralBurst;
      case DocumentType.reservation:
        return AppColors.skyBlue;
      case DocumentType.passport:
        return AppColors.lavenderDream;
      case DocumentType.visa:
        return AppColors.sunnyYellow;
      case DocumentType.insurance:
        return AppColors.oceanTeal;
      case DocumentType.itinerary:
        return AppColors.goldenGlow;
      case DocumentType.other:
        return AppColors.slate;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showSourceDialog() {
    HapticFeedback.lightImpact();

    final remainingSlots = _maxFilesPerDocument - _selectedFiles.length;
    if (remainingSlots <= 0) {
      _showError('Maximum $_maxFilesPerDocument files allowed');
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Document',
                style: AppTypography.headlineSmall.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.space20),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: AppColors.oceanTeal,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromCamera();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      color: AppColors.skyBlue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFromGallery();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Expanded(
                    child: _buildSourceOption(
                      icon: Icons.folder_rounded,
                      label: 'Files',
                      color: AppColors.lavenderDream,
                      onTap: () {
                        Navigator.pop(context);
                        _pickFiles();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: AppSizes.space8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();

        if (fileSize > _maxFileSizeBytes) {
          _showError('Photo exceeds 10MB limit');
          return;
        }

        final fileName = image.name.isNotEmpty
            ? image.name
            : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final platformFile = fp.PlatformFile(
          path: image.path,
          name: fileName,
          size: fileSize,
        );

        setState(() {
          _selectedFiles.add(platformFile);
          if (_nameController.text.isEmpty && _selectedFiles.length == 1) {
            final name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
            _nameController.text = name;
          }
        });
      }
    } catch (e) {
      _showError('Error capturing photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final validFiles = <fp.PlatformFile>[];

        for (final image in images) {
          final file = File(image.path);
          final fileSize = await file.length();

          if (fileSize > _maxFileSizeBytes) {
            _showError('Photo "${image.name}" exceeds 10MB limit');
            continue;
          }

          if (validFiles.length + _selectedFiles.length >= _maxFilesPerDocument) {
            _showError('Maximum $_maxFilesPerDocument files allowed');
            break;
          }

          final fileName = image.name.isNotEmpty
              ? image.name
              : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

          validFiles.add(fp.PlatformFile(
            path: image.path,
            name: fileName,
            size: fileSize,
          ));
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(validFiles);
            if (_nameController.text.isEmpty && _selectedFiles.length == 1) {
              final name = _selectedFiles.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
              _nameController.text = name;
            }
          });
        }
      }
    } catch (e) {
      _showError('Error picking photos: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final validFiles = <fp.PlatformFile>[];

        for (final file in result.files) {
          // Check file size (10MB max)
          if (file.size > _maxFileSizeBytes) {
            _showError('File "${file.name}" exceeds 10MB limit');
            continue;
          }

          // Check if we have room
          if (validFiles.length + _selectedFiles.length >= _maxFilesPerDocument) {
            _showError('Maximum $_maxFilesPerDocument files allowed');
            break;
          }

          validFiles.add(file);
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedFiles.addAll(validFiles);
            // Auto-fill name if empty and only one file
            if (_nameController.text.isEmpty && _selectedFiles.length == 1) {
              final name = _selectedFiles.first.name.replaceAll(RegExp(r'\.[^.]+$'), '');
              _nameController.text = name;
            }
          });
        }
      }
    } catch (e) {
      _showError('Error picking files: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty) {
      _showError('Please select at least one file');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Build selected document files list
      final documentFiles = _selectedFiles.map((file) {
        final mimeType = _getMimeType(file.extension ?? '');
        return SelectedDocumentFile(
          file: File(file.path!),
          fileName: file.name,
          mimeType: mimeType,
        );
      }).toList();

      await ref.read(tripDocumentsProvider(widget.tripId).notifier).uploadDocument(
            name: _nameController.text.trim(),
            files: documentFiles,
            type: _selectedType.name,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            onProgress: (sent, total) {
              if (mounted) {
                setState(() => _uploadProgress = sent / total);
              }
            },
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Text(_selectedFiles.length == 1
                    ? 'Document uploaded'
                    : '${_selectedFiles.length} files uploaded'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to upload: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}
