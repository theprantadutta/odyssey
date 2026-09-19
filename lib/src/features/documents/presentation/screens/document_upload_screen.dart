import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../subscription/presentation/utils/limit_checker.dart';
import '../../data/models/document_model.dart';
import '../../data/repositories/document_repository.dart';
import '../providers/documents_provider.dart';

/// Default maximum number of files per document, used when the subscription
/// tier does not say otherwise.
const int _defaultMaxFilesPerDocument = 10;

/// Maximum file size (10MB).
const int _maxFileSizeBytes = 10 * 1024 * 1024;

/// Add a document: one or more files, a name, a kind and a note.
class DocumentUploadScreen extends ConsumerStatefulWidget {
  const DocumentUploadScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  final List<fp.PlatformFile> _selectedFiles = [];
  DocumentType _type = DocumentType.other;
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  /// The file limit depends on the user's subscription tier.
  int get _maxFiles =>
      LimitChecker.getFilesPerDocumentLimit(ref) ?? _defaultMaxFilesPerDocument;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _selectedFiles.isNotEmpty &&
      _nameController.text.trim().isNotEmpty &&
      !_isLoading;

  String get _submitLabel {
    if (_isLoading) return 'Uploading · ${(_uploadProgress * 100).round()}%';
    if (_selectedFiles.isEmpty) return 'Choose a file';
    if (_nameController.text.trim().isEmpty) return 'Name the document';
    return _selectedFiles.length == 1
        ? 'Add to the wallet'
        : 'Add ${_selectedFiles.length} files';
  }

  /// Fills the name from the first file, so the common case needs no typing.
  void _autofillName() {
    if (_nameController.text.isNotEmpty || _selectedFiles.length != 1) return;
    _nameController.text = _selectedFiles.first.name.replaceAll(
      RegExp(r'\.[^.]+$'),
      '',
    );
  }

  Future<void> _addFrom() async {
    if (_selectedFiles.length >= _maxFiles) {
      showOdysseyMessage(context, 'That is $_maxFiles files — the limit.');
      return;
    }

    final choice = await showOdysseyPicker<String>(
      context: context,
      title: 'Add a file',
      options: const ['Take a photo', 'Photo library', 'Browse files'],
      labelOf: (value) => value,
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'Take a photo':
        await _pickFromCamera();
      case 'Photo library':
        await _pickFromGallery();
      case 'Browse files':
        await _pickFiles();
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return;

      final size = await File(image.path).length();
      if (size > _maxFileSizeBytes) {
        if (mounted) {
          showOdysseyMessage(context, 'That photo is over the 10MB limit.');
        }
        return;
      }

      final name = image.name.isNotEmpty
          ? image.name
          : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      setState(() {
        _selectedFiles.add(
          fp.PlatformFile(path: image.path, name: name, size: size),
        );
        _autofillName();
      });
    } catch (e) {
      if (mounted) showOdysseyMessage(context, 'Could not take that: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final images = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (images.isEmpty) return;

      final accepted = <fp.PlatformFile>[];
      for (final image in images) {
        final size = await File(image.path).length();
        if (size > _maxFileSizeBytes) {
          if (mounted) {
            showOdysseyMessage(
              context,
              '"${image.name}" is over the 10MB limit.',
            );
          }
          continue;
        }
        if (accepted.length + _selectedFiles.length >= _maxFiles) {
          if (mounted) {
            showOdysseyMessage(context, 'That is $_maxFiles files — the limit.');
          }
          break;
        }
        accepted.add(
          fp.PlatformFile(
            path: image.path,
            name: image.name.isNotEmpty
                ? image.name
                : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
            size: size,
          ),
        );
      }

      if (accepted.isEmpty) return;
      setState(() {
        _selectedFiles.addAll(accepted);
        _autofillName();
      });
    } catch (e) {
      if (mounted) showOdysseyMessage(context, 'Could not open those: $e');
    }
  }

  Future<void> _pickFiles() async {
    try {
      // file_picker 12.x: the methods are static on FilePicker, and pickFiles
      // defaults to multiple selection.
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (result == null || result.files.isEmpty) return;

      final accepted = <fp.PlatformFile>[];
      for (final file in result.files) {
        if (file.size > _maxFileSizeBytes) {
          if (mounted) {
            showOdysseyMessage(
              context,
              '"${file.name}" is over the 10MB limit.',
            );
          }
          continue;
        }
        if (accepted.length + _selectedFiles.length >= _maxFiles) {
          if (mounted) {
            showOdysseyMessage(context, 'That is $_maxFiles files — the limit.');
          }
          break;
        }
        accepted.add(file);
      }

      if (accepted.isEmpty) return;
      setState(() {
        _selectedFiles.addAll(accepted);
        _autofillName();
      });
    } catch (e) {
      if (mounted) showOdysseyMessage(context, 'Could not open those: $e');
    }
  }

  Future<void> _upload() async {
    final currentCount =
        ref.read(tripDocumentsProvider(widget.tripId)).documents.length;
    final canCreate = await LimitChecker.canCreateDocument(
      context,
      ref,
      currentCount: currentCount,
    );
    if (!canCreate || !mounted) return;

    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty) {
      showOdysseyMessage(context, 'Choose at least one file.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final files = _selectedFiles
          .map(
            (file) => SelectedDocumentFile(
              file: File(file.path!),
              fileName: file.name,
              mimeType: _mimeType(file.extension ?? ''),
            ),
          )
          .toList();

      final notes = _notesController.text.trim();

      await ref
          .read(tripDocumentsProvider(widget.tripId).notifier)
          .uploadDocument(
            name: _nameController.text.trim(),
            files: files,
            type: _type.name,
            notes: notes.isEmpty ? null : notes,
            onProgress: (sent, total) {
              if (mounted) setState(() => _uploadProgress = sent / total);
            },
          );

      if (!mounted) return;
      Navigator.of(context).pop();
      showOdysseyMessage(
        context,
        _selectedFiles.length == 1
            ? 'Added to the wallet.'
            : '${_selectedFiles.length} files added.',
      );
    } catch (e) {
      if (mounted) showOdysseyMessage(context, 'That did not upload: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _mimeType(String extension) => switch (extension.toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };

  @override
  Widget build(BuildContext context) {
    return OdysseyFormScreen(
      formKey: _formKey,
      onChanged: () => setState(() {}),
      title: 'New document',
      subtitle: 'Tickets, bookings, anything worth having offline.',
      submitLabel: _submitLabel,
      isLoading: _isLoading,
      onSubmit: _canSubmit ? _upload : null,
      children: [
        _FileList(
          files: _selectedFiles,
          onAdd: _addFrom,
          onRemove: (index) => setState(() => _selectedFiles.removeAt(index)),
        ),
        const SizedBox(height: AppSizes.space18),

        FieldCard(
          label: 'Name',
          controller: _nameController,
          hint: 'Flight to Osaka',
          textCapitalization: TextCapitalization.sentences,
          validator: (value) => Validators.required(value, fieldName: 'Name'),
        ),
        const SizedBox(height: AppSizes.space20),

        FormGroup(
          label: 'Kind',
          child: ChipWrap(
            labels: DocumentType.values.map((d) => d.displayName).toList(),
            selected: _type.displayName,
            onSelected: (label) => setState(() {
              _type = DocumentType.values.firstWhere(
                (d) => d.displayName == label,
              );
            }),
          ),
        ),
        const SizedBox(height: AppSizes.space20),

        FieldCard(
          label: 'Notes',
          controller: _notesController,
          hint: 'Seat, gate, confirmation number',
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

/// The chosen files, as rows with an extension thumb, ending in a dashed add
/// affordance.
class _FileList extends StatelessWidget {
  const _FileList({
    required this.files,
    required this.onAdd,
    required this.onRemove,
  });

  final List<fp.PlatformFile> files;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    if (files.isEmpty) {
      return DashedBox(
        radius: AppSizes.radiusTile,
        height: 130,
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
              'Choose a file or take a photo',
              style: AppTypography.legend.copyWith(color: t.ink3),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < files.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.space10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(AppSizes.radiusRow),
              border: Border.all(color: t.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 42,
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    color: t.cardAlt,
                    borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                    border: Border.all(color: t.hairline),
                  ),
                  child: Text(
                    (files[i].extension ?? '').toUpperCase(),
                    style: AppTypography.fileExt.copyWith(color: t.ink3),
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        files[i].name,
                        style: AppTypography.rowTitle.copyWith(color: t.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _size(files[i].size),
                        style: AppTypography.rowMeta.copyWith(color: t.ink3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.space10),
                CircleButton(
                  glyph: '✕',
                  size: AppSizes.circleSm,
                  onPressed: () => onRemove(i),
                  semanticLabel: 'Remove ${files[i].name}',
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSizes.space10),
        PillButton(
          label: 'Add another file',
          style: PillStyle.dashed,
          onPressed: onAdd,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ],
    );
  }
}
