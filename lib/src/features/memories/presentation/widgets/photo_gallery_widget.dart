import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/utils/file_url_helper.dart';
import '../../data/models/memory_model.dart';

/// Photo/video gallery grid widget for displaying memories
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
        return MediaThumbnail(
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

/// Individual media thumbnail widget (photo or video)
class MediaThumbnail extends StatelessWidget {
  final MemoryModel memory;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MediaThumbnail({
    super.key,
    required this.memory,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayUrl = memory.displayUrl;
    final hasVideo = memory.hasVideo;
    final mediaCount = memory.mediaItems.length;

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
                // Photo/Video thumbnail or placeholder
                if (displayUrl != null)
                  CachedNetworkImage(
                    imageUrl: FileUrlHelper.getAuthenticatedUrl(displayUrl),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.sunnyYellow,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: theme.hintColor,
                      ),
                    ),
                  )
                else
                  // No media - show caption indicator
                  Container(
                    color: AppColors.lemonLight,
                    child: Center(
                      child: Icon(
                        Icons.notes_rounded,
                        size: 32,
                        color: AppColors.goldenGlow,
                      ),
                    ),
                  ),

                // Video play indicator
                if (hasVideo)
                  Positioned(
                    top: AppSizes.space4,
                    left: AppSizes.space4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                // Media count badge (if multiple media items)
                if (mediaCount > 1)
                  Positioned(
                    top: AppSizes.space4,
                    right: AppSizes.space4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$mediaCount',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

/// Legacy alias for backwards compatibility
typedef PhotoThumbnail = MediaThumbnail;

/// Empty state for memories
class NoMemoriesState extends StatelessWidget {
  final VoidCallback? onAddMemory;

  const NoMemoriesState({
    super.key,
    this.onAddMemory,
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
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            // Description
            Text(
              'Capture your favorite moments by uploading photos and videos from your trip.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
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

/// Media count badge widget (updated from photo count)
class MediaCountBadge extends StatelessWidget {
  final int photoCount;
  final int videoCount;

  const MediaCountBadge({
    super.key,
    required this.photoCount,
    this.videoCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = photoCount + videoCount;

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
            videoCount > 0 ? Icons.perm_media_rounded : Icons.photo_library_rounded,
            size: AppSizes.iconXs,
            color: AppColors.goldenGlow,
          ),
          const SizedBox(width: AppSizes.space4),
          Text(
            '$totalCount ${totalCount == 1 ? 'Memory' : 'Memories'}',
            style: AppTypography.caption.copyWith(
              color: AppColors.goldenGlow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy alias for backwards compatibility
typedef PhotoCountBadge = MediaCountBadge;
