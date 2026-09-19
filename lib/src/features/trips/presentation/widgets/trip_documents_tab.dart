import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/task_routes.dart';
import '../../../documents/data/models/document_model.dart';
import '../../../documents/presentation/providers/documents_provider.dart';
import '../../../documents/presentation/screens/document_upload_screen.dart';
import '../../../documents/presentation/screens/pdf_viewer_screen.dart';
import '../../../documents/presentation/widgets/document_image_viewer.dart';

/// The travel wallet — screen 3j.
///
/// A boarding-pass card for the trip's ticket, filter chips, and file rows
/// with an extension-labelled thumb.
class TripDocumentsTab extends ConsumerStatefulWidget {
  const TripDocumentsTab({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDocumentsTab> createState() => _TripDocumentsTabState();
}

class _TripDocumentsTabState extends ConsumerState<TripDocumentsTab> {
  static const String _allFilters = 'All';
  String _filter = _allFilters;

  static String _typeLabel(String raw) => DocumentType.values
      .firstWhere((t) => t.name == raw, orElse: () => DocumentType.other)
      .displayName;

  void _upload() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.documentUpload),
        builder: (context) => DocumentUploadScreen(tripId: widget.tripId),
      ),
    );
  }

  Future<void> _delete(DocumentModel document) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete document',
      body: [
        'This removes "${document.name}" and any files attached to it. '
            'It cannot be undone.',
      ],
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    await ref
        .read(tripDocumentsProvider(widget.tripId).notifier)
        .deleteDocument(document.id);
  }

  Future<void> _open(DocumentModel document) async {
    HapticFeedback.lightImpact();

    final primaryFile = document.primaryFile;
    final url = document.primaryUrl;

    if (url == null || url.isEmpty) {
      showOdysseyMessage(
        context,
        'Nothing attached to this one yet. Upload a file to view it.',
      );
      return;
    }

    if (primaryFile?.isPdf == true) {
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: TaskRoutes.settings(TaskRoutes.pdfViewer),
          builder: (context) =>
              PdfViewerScreen(url: url, title: document.name),
        ),
      );
      return;
    }

    if (primaryFile?.isImage == true) {
      final images = document.files.where((f) => f.isImage).toList();
      if (images.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          settings: TaskRoutes.settings(TaskRoutes.photoViewer),
          builder: (context) => DocumentImageViewer(
            images: images.map((f) => f.url).toList(),
            title: document.name,
          ),
        ),
      );
      return;
    }

    // Anything else goes to whatever the platform has for it.
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        showOdysseyMessage(context, 'Nothing on this device can open that.');
      }
    } catch (e) {
      if (mounted) showOdysseyMessage(context, 'That would not open: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final state = ref.watch(tripDocumentsProvider(widget.tripId));

    if (state.isLoading && state.documents.isEmpty) {
      return const Column(
        children: [
          Skeleton(width: double.infinity, height: 190, radius: AppSizes.radiusHero),
          SizedBox(height: AppSizes.space12),
          Skeleton.row(),
        ],
      );
    }

    if (state.error != null && state.documents.isEmpty) {
      return OdysseyErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(tripDocumentsProvider(widget.tripId).notifier).refresh(),
      );
    }

    if (state.documents.isEmpty) {
      return OdysseyEmptyState(
        message: 'The wallet is empty. Tickets and bookings live here.',
        actionLabel: 'Upload a document',
        onAction: _upload,
      );
    }

    // The boarding pass is the trip's ticket, if it has one. It is the one
    // document the design gives its own card, because it is the one you open
    // standing at a gate.
    final ticket = state.documents
        .where((d) => d.type == DocumentType.ticket.name)
        .firstOrNull;

    final types = <String>{
      _allFilters,
      ...state.documents.map((d) => _typeLabel(d.type)),
    }.toList();

    final visible = _filter == _allFilters
        ? state.documents
        : state.documents
              .where((d) => _typeLabel(d.type) == _filter)
              .toList();

    final offline = state.documents.where((d) => d.files.isNotEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Travel wallet',
          style: AppTypography.screenTitle.copyWith(color: t.ink),
        ),
        const SizedBox(height: AppSizes.space8),
        Text(
          '${state.documents.length} '
          '${state.documents.length == 1 ? 'file' : 'files'} · '
          '$offline available offline',
          style: AppTypography.meta.copyWith(color: t.ink3),
        ),
        const SizedBox(height: AppSizes.space18),

        if (ticket != null) ...[
          _BoardingPassCard(document: ticket, onTap: () => _open(ticket)),
          const SizedBox(height: AppSizes.space18),
        ],

        if (types.length > 2) ...[
          ChipRow(
            labels: types,
            selected: _filter,
            activeStyle: ChipActiveStyle.action,
            onSelected: (value) => setState(() => _filter = value),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSizes.space16),
        ],

        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSizes.space10),
          _DocumentRow(
            document: visible[i],
            onTap: () => _open(visible[i]),
            onLongPress: () => _delete(visible[i]),
          ),
        ],

        const SizedBox(height: AppSizes.space14),
        PillButton(
          label: 'Upload a document',
          style: PillStyle.dashed,
          onPressed: _upload,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ],
    );
  }
}

/// The ticket, given its own card: the boarding-pass gradient, the route set
/// large, and a barcode strip.
class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({required this.document, required this.onTap});

  final DocumentModel document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusHero),
      tint: false,
      child: PhotoSurface(
        gradient: AppColors.boardingPassGradient,
        radius: AppSizes.radiusHero,
        scrim: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.space20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: EyebrowLabel(
                      'Boarding pass',
                      color: AppColors.onPhoto3,
                    ),
                  ),
                  if (document.files.isNotEmpty) const OdysseyBadge('SAVED'),
                ],
              ),
              const SizedBox(height: AppSizes.space12),
              Text(
                document.name,
                style: AppTypography.route.copyWith(color: AppColors.onPhoto),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (document.notes != null && document.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSizes.space10),
                Text(
                  document.notes!,
                  style: AppTypography.meta.copyWith(
                    color: AppColors.onPhoto2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSizes.space20),
              // A decorative strip, not a scannable code. The real barcode
              // lives inside the attached file, which is what tapping opens.
              const _BarcodeStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeStrip extends StatelessWidget {
  const _BarcodeStrip();

  @override
  Widget build(BuildContext context) {
    // A fixed pattern rather than a random one, so the card does not reshuffle
    // itself on every rebuild.
    const opacities = [1.0, 0.7, 0.35, 1.0, 0.35, 0.7, 1.0, 0.35, 1.0, 0.7];

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (var i = 0; i < 42; i++) ...[
            if (i > 0) const SizedBox(width: 2.5),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.onPhoto.withValues(
                    alpha: opacities[i % opacities.length] * 0.85,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One file: an extension-labelled thumb, the name, and its format and size.
class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.onTap,
    required this.onLongPress,
  });

  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final file = document.primaryFile;

    final meta = [
      _TripDocumentsTabState._typeLabel(document.type),
      if (file != null && file.formattedSize.isNotEmpty) file.formattedSize,
      if (document.notes != null && document.notes!.isNotEmpty) document.notes!,
    ].join(' · ');

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppSizes.radiusRow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
          border: Border.all(color: t.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 52,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: t.cardAlt,
                borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                border: Border.all(color: t.hairline),
              ),
              child: Text(
                (file?.extension ?? '').toUpperCase(),
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
                    document.name,
                    style: AppTypography.rowTitle.copyWith(color: t.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: AppTypography.rowMeta.copyWith(color: t.ink3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.space8),
            Text(
              '→',
              style: AppTypography.glyph.copyWith(fontSize: 16, color: t.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
