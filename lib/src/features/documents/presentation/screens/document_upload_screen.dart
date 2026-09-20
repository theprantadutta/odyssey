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

/// A file the user chose, whichever picker it came from.
///
/// This screen used to pass file_picker's own PlatformFile around, and
/// constructed one by hand for photos that never came from that picker at all.
/// Version 13 made PlatformFile an abstract base class, which is a reasonable
/// thing for a package to do with its own type - the mistake was borrowing it.
/// Both pickers convert into this instead.
class PickedFile {
  const PickedFile({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;

  /// Length in bytes, resolved when the file was picked. file_picker 13 reports
  /// this asynchronously, so it is read once here rather than at every use.
  final int size;

  /// The extension of [name] without the leading dot, or null if it has none.
  ///
  /// A name that begins with a dot is a dotfile, not an extension, and a name
  /// that ends with one has no extension either.
  String? get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1);
  }
}

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

  final List<PickedFile> _selectedFiles = [];
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
          PickedFile(path: image.path, name: name, size: size),
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

      final accepted = <PickedFile>[];
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
          PickedFile(
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
      // file_picker 13: the methods are static on FilePicker, pickFiles
      // defaults to multiple selection, and it returns the files directly -
      // an empty list where it used to return null for a cancelled picker.
      final picked = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (picked.isEmpty) return;

      final accepted = <PickedFile>[];
      for (final file in picked) {
        // Not everything a picker can return lives on disk - a cloud provider
        // can hand back a file with no local path. The upload reads from a
        // path, so one without is declined rather than silently dropped.
        final path = file.path;
        if (path == null) {
          if (mounted) {
            showOdysseyMessage(
              context,
              '"${file.name}" is not stored on this device. Download it first.',
            );
          }
          continue;
        }

        // length() is null when the picker could not work the size out, which
        // is not the same as an empty file. We already know this one is on
        // disk, so ask the disk rather than wave the limit through.
        final size = await file.length() ?? await File(path).length();
        if (size > _maxFileSizeBytes) {
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
        accepted.add(PickedFile(path: path, name: file.name, size: size));
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
              file: File(file.path),
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

  final List<PickedFile> files;
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
