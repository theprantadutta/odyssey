import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/document_repository.dart';
import '../providers/documents_provider.dart';

/// Screen for uploading a document
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
  fp.PlatformFile? _selectedFile;
  bool _isLoading = false;

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
    return Scaffold(
      backgroundColor: AppColors.snowWhite,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.space20),
          children: [
            // File picker
            _buildFilePicker(),
            const SizedBox(height: AppSizes.space20),

            // Name field
            _buildNameField(),
            const SizedBox(height: AppSizes.space20),

            // Type selector
            _buildTypeSelector(),
            const SizedBox(height: AppSizes.space20),

            // Notes field
            _buildNotesField(),
            const SizedBox(height: AppSizes.space32),

            // Upload button
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.snowWhite,
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
            color: AppColors.warmGray,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.charcoal,
          ),
        ),
      ),
      title: Text(
        'Upload Document',
        style: AppTypography.headlineSmall.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select File',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.space20),
            decoration: BoxDecoration(
              color: AppColors.warmGray,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: _selectedFile != null
                    ? AppColors.lavenderDream
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: _selectedFile != null
                ? _buildSelectedFilePreview()
                : _buildFilePickerPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePickerPlaceholder() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.lavenderDream.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.upload_file_rounded,
            size: 32,
            color: AppColors.lavenderDream,
          ),
        ),
        const SizedBox(height: AppSizes.space12),
        Text(
          'Tap to select file',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: AppSizes.space4),
        Text(
          'PDF, JPG, PNG (max 10MB)',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedFilePreview() {
    final isImage = _selectedFile!.extension?.toLowerCase() == 'jpg' ||
        _selectedFile!.extension?.toLowerCase() == 'jpeg' ||
        _selectedFile!.extension?.toLowerCase() == 'png' ||
        _selectedFile!.extension?.toLowerCase() == 'webp';

    return Row(
      children: [
        // Icon or thumbnail
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _selectedFile!.extension?.toLowerCase() == 'pdf'
                ? AppColors.coralBurst.withValues(alpha: 0.1)
                : AppColors.skyBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: isImage && _selectedFile!.path != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  child: Image.file(
                    File(_selectedFile!.path!),
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(
                  _selectedFile!.extension?.toLowerCase() == 'pdf'
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_rounded,
                  size: 28,
                  color: _selectedFile!.extension?.toLowerCase() == 'pdf'
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
                _selectedFile!.name,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSizes.space4),
              Text(
                _formatFileSize(_selectedFile!.size),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
        ),

        // Change button
        IconButton(
          onPressed: _pickFile,
          icon: const Icon(
            Icons.edit_rounded,
            color: AppColors.lavenderDream,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document Name',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.charcoal),
          decoration: InputDecoration(
            hintText: 'e.g., Flight to Paris, Hotel Booking...',
            hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.slate),
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

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document Type',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
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
                      : AppColors.warmGray,
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
                        color: isSelected ? Colors.white : AppColors.charcoal,
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

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        TextFormField(
          controller: _notesController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.charcoal),
          decoration: InputDecoration(
            hintText: 'Add any notes or reminders...',
            hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.slate),
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
              borderSide:
                  const BorderSide(color: AppColors.lavenderDream, width: 2),
            ),
            contentPadding: const EdgeInsets.all(AppSizes.space16),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    final isEnabled = _selectedFile != null && !_isLoading;

    return GestureDetector(
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
              : Text(
                  'Upload Document',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

  Future<void> _pickFile() async {
    HapticFeedback.lightImpact();

    try {
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (10MB max)
        if (file.size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('File size must be less than 10MB'),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
          // Auto-fill name if empty
          if (_nameController.text.isEmpty) {
            final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
            _nameController.text = name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
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

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final mimeType = _getMimeType(_selectedFile!.extension ?? '');

      // Create a SelectedDocumentFile from the picked file
      final documentFile = SelectedDocumentFile(
        file: File(_selectedFile!.path!),
        fileName: _selectedFile!.name,
        mimeType: mimeType,
      );

      await ref.read(tripDocumentsProvider(widget.tripId).notifier).uploadDocument(
            name: _nameController.text.trim(),
            files: [documentFile],
            type: _selectedType.name,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: AppSizes.space12),
                Text('Document uploaded'),
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
