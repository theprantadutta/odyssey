import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/document_model.dart';
import 'document_card.dart';

/// Widget displaying documents grouped by type
class DocumentListWidget extends StatelessWidget {
  final List<DocumentsByType> groupedDocuments;
  final Function(DocumentModel) onDocumentTap;
  final Function(DocumentModel)? onDocumentDelete;

  const DocumentListWidget({
    super.key,
    required this.groupedDocuments,
    required this.onDocumentTap,
    this.onDocumentDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (groupedDocuments.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.space16),
      itemCount: groupedDocuments.length,
      itemBuilder: (context, index) {
        final group = groupedDocuments[index];
        return _DocumentTypeSection(
          group: group,
          onDocumentTap: onDocumentTap,
          onDocumentDelete: onDocumentDelete,
        );
      },
    );
  }
}

class _DocumentTypeSection extends StatelessWidget {
  final DocumentsByType group;
  final Function(DocumentModel) onDocumentTap;
  final Function(DocumentModel)? onDocumentDelete;

  const _DocumentTypeSection({
    required this.group,
    required this.onDocumentTap,
    this.onDocumentDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final docType = DocumentType.fromString(group.type);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.space12,
              vertical: AppSizes.space8,
            ),
            decoration: BoxDecoration(
              color: _getTypeColor(docType).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Row(
              children: [
                Text(
                  docType.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: AppSizes.space8),
                Expanded(
                  child: Text(
                    docType.displayName,
                    style: AppTypography.titleSmall.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space8,
                    vertical: AppSizes.space4,
                  ),
                  decoration: BoxDecoration(
                    color: _getTypeColor(docType).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Text(
                    '${group.count}',
                    style: AppTypography.labelSmall.copyWith(
                      color: _getTypeColor(docType),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.space12),

          // Documents list
          ...group.documents.map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.space8),
                child: DocumentCard(
                  document: doc,
                  onTap: () => onDocumentTap(doc),
                  onDelete:
                      onDocumentDelete != null ? () => onDocumentDelete!(doc) : null,
                ),
              )),
        ],
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
}

/// Empty state for documents
class NoDocumentsState extends StatelessWidget {
  final VoidCallback? onUpload;

  const NoDocumentsState({
    super.key,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.lavenderDream.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Center(
                child: Text(
                  '📄',
                  style: TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'No documents yet',
              style: AppTypography.headlineMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              'Upload tickets, reservations, and other travel documents',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (onUpload != null) ...[
              const SizedBox(height: AppSizes.space24),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onUpload!();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space20,
                    vertical: AppSizes.space12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderDream,
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.lavenderDream.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.upload_file_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: AppSizes.space8),
                      Text(
                        'Upload Document',
                        style: AppTypography.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
