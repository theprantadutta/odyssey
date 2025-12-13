import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../data/models/memory_model.dart';

/// Photo gallery grid widget for displaying memories
class PhotoGalleryWidget extends StatelessWidget {
  final List<MemoryModel> memories;
  final Function(MemoryModel memory, int index)? onPhotoTap;
  final Function(MemoryModel memory)? onPhotoLongPress;

  const PhotoGalleryWidget({
    super.key,
    required this.memories,
    this.onPhotoTap,
    this.onPhotoLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (memories.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.space16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSizes.space8,
        mainAxisSpacing: AppSizes.space8,
        childAspectRatio: 1.0,
      ),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        return PhotoThumbnail(
          memory: memory,
          onTap: () {
            HapticFeedback.lightImpact();
            onPhotoTap?.call(memory, index);
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onPhotoLongPress?.call(memory);
          },
        );
      },
    );
  }
}

/// Individual photo thumbnail widget
class PhotoThumbnail extends StatelessWidget {
  final MemoryModel memory;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const PhotoThumbnail({
    super.key,
    required this.memory,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Hero(
        tag: 'memory-${memory.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            boxShadow: AppSizes.softShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo
                CachedNetworkImage(
                  imageUrl: memory.photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.warmGray,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.sunnyYellow,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.warmGray,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.mutedGray,
                    ),
                  ),
                ),
                // Date overlay
                if (memory.takenAt != null || memory.createdAt.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space8,
                        vertical: AppSizes.space4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      child: Text(
                        _formatDate(memory.takenAt ?? memory.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return '';
    }
  }
}

/// Empty state for memories
class NoMemoriesState extends StatelessWidget {
  final VoidCallback? onAddMemory;

  const NoMemoriesState({
    super.key,
    this.onAddMemory,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Center(
                child: Text(
                  '📸',
                  style: TextStyle(fontSize: 36),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            // Title
            Text(
              'No Memories Yet',
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.charcoal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            // Description
            Text(
              'Capture your favorite moments by uploading photos from your trip.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            // Add button
            if (onAddMemory != null)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onAddMemory?.call();
                },
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Add First Memory'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sunnyYellow,
                  backgroundColor: AppColors.lemonLight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space20,
                    vertical: AppSizes.space12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Photo count badge widget
class PhotoCountBadge extends StatelessWidget {
  final int count;

  const PhotoCountBadge({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space12,
        vertical: AppSizes.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.lemonLight,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_rounded,
            size: AppSizes.iconXs,
            color: AppColors.goldenGlow,
          ),
          const SizedBox(width: AppSizes.space4),
          Text(
            '$count ${count == 1 ? 'Photo' : 'Photos'}',
            style: AppTypography.caption.copyWith(
              color: AppColors.goldenGlow,
            ),
          ),
        ],
      ),
    );
  }
}
