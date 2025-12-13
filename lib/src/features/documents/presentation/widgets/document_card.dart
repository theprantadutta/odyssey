import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/document_model.dart';

/// Card widget for displaying a document
class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final docType = DocumentType.fromString(document.type);
    final fileType = FileType.fromString(document.fileType);

    return Dismissible(
      key: Key(document.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSizes.space20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        if (onDelete != null) {
          HapticFeedback.mediumImpact();
          onDelete!();
        }
        return false;
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(AppSizes.space12),
          decoration: BoxDecoration(
            color: AppColors.snowWhite,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.warmGray, width: 1),
          ),
          child: Row(
            children: [
              // Thumbnail or icon
              _buildThumbnail(fileType),

              const SizedBox(width: AppSizes.space12),

              // Document info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.name,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.charcoal,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.space8,
                            vertical: AppSizes.space4,
                          ),
                          decoration: BoxDecoration(
                            color: _getTypeColor(docType).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                docType.icon,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: AppSizes.space4),
                              Text(
                                docType.displayName,
                                style: AppTypography.labelSmall.copyWith(
                                  color: _getTypeColor(docType),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSizes.space8),
                        Text(
                          fileType.displayName,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                    if (document.notes != null && document.notes!.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.space4),
                      Text(
                        document.notes!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.slate,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: AppSizes.space8),

              // Arrow
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.slate,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(FileType fileType) {
    if (fileType == FileType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: CachedNetworkImage(
          imageUrl: document.fileUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 56,
            height: 56,
            color: AppColors.warmGray,
            child: const Icon(
              Icons.image_rounded,
              color: AppColors.slate,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 56,
            height: 56,
            color: AppColors.warmGray,
            child: const Icon(
              Icons.broken_image_rounded,
              color: AppColors.slate,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: fileType == FileType.pdf
            ? AppColors.coralBurst.withValues(alpha: 0.1)
            : AppColors.warmGray,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Center(
        child: Icon(
          fileType == FileType.pdf
              ? Icons.picture_as_pdf_rounded
              : Icons.insert_drive_file_rounded,
          color: fileType == FileType.pdf ? AppColors.coralBurst : AppColors.slate,
          size: 28,
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
}
