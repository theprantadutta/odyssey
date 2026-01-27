import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/animations/loading/bouncing_dots_loader.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../memories/presentation/providers/memories_provider.dart';
import '../../../memories/presentation/screens/photo_upload_screen.dart';
import '../../../memories/presentation/screens/photo_viewer_screen.dart';
import '../../../memories/presentation/widgets/photo_gallery_widget.dart';

class TripMemoriesTab extends ConsumerWidget {
  final String tripId;

  const TripMemoriesTab({
    super.key,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final memoriesState = ref.watch(tripMemoriesProvider(tripId));

    return Stack(
      children: [
        // Main content
        _buildContent(context, ref, memoriesState, theme, colorScheme),
        // FAB
        Positioned(
          right: AppSizes.space16,
          bottom: AppSizes.space16,
          child: _buildFAB(context),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    MemoriesState state,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // Loading state
    if (state.isLoading && state.memories.isEmpty) {
      return _buildLoadingState(colorScheme);
    }

    // Error state
    if (state.error != null && state.memories.isEmpty) {
      return _buildErrorState(context, ref, state.error!, colorScheme);
    }

    // Empty state
    if (state.memories.isEmpty) {
      return NoMemoriesState(
        onAddMemory: () => _navigateToUpload(context),
      );
    }

    // Memories gallery
    return RefreshIndicator(
      color: AppColors.sunnyYellow,
      onRefresh: () async {
        await ref.read(tripMemoriesProvider(tripId).notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: AppSizes.space80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space16,
                vertical: AppSizes.space16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${state.memories.length} ${state.memories.length == 1 ? 'Memory' : 'Memories'}',
                    style: AppTypography.titleSmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  MediaCountBadge(
                    photoCount: state.memories.where((m) => !m.hasVideo).length,
                    videoCount: state.memories.where((m) => m.hasVideo).length,
                  ),
                ],
              ),
            ),
            // Photo gallery
            PhotoGalleryWidget(
              memories: state.memories,
              onPhotoTap: (memory, index) {
                _navigateToViewer(context, state.memories, index);
              },
              onPhotoLongPress: (memory) {
                _showDeleteDialog(context, ref, memory);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OrbitalLoader(size: 64),
          const SizedBox(height: 20),
          Text(
            'Loading memories...',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusXl),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.space24),
            Text(
              'Failed to load memories',
              style: AppTypography.headlineMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space8),
            Text(
              error,
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(tripMemoriesProvider(tripId).notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
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

  Widget _buildFAB(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _navigateToUpload(context);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.sunnyYellow,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.sunnyYellow.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_a_photo_rounded,
          color: AppColors.charcoal,
          size: 28,
        ),
      ),
    );
  }

  void _navigateToUpload(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PhotoUploadScreen(tripId: tripId),
      ),
    );
  }

  void _navigateToViewer(
    BuildContext context,
    List memories,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PhotoViewerScreen(
          tripId: tripId,
          memories: List.from(memories),
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic memory,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Text(
          'Delete Memory',
          style: AppTypography.headlineSmall.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this memory? This action cannot be undone.',
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop();
              try {
                await ref
                    .read(tripMemoriesProvider(tripId).notifier)
                    .deleteMemory(memory.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: AppSizes.space12),
                          Text('Memory deleted'),
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
