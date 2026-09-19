import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/router/task_routes.dart';
import '../../../memories/data/models/memory_model.dart';
import '../../../memories/presentation/providers/memories_provider.dart';
import '../../../memories/presentation/screens/photo_upload_screen.dart';
import '../../../memories/presentation/screens/photo_viewer_screen.dart';

/// The memory wall from screen 3g.
///
/// A two-column grid where the first tile spans two rows, and the last cell is
/// a dashed "add photo" affordance.
class TripMemoriesTab extends ConsumerWidget {
  const TripMemoriesTab({super.key, required this.tripId});

  final String tripId;

  void _upload(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: TaskRoutes.settings(TaskRoutes.photoUpload),
        builder: (context) => PhotoUploadScreen(tripId: tripId),
      ),
    );
  }

  void _openViewer(
    BuildContext context,
    List<MemoryModel> memories,
    int index,
  ) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        settings: TaskRoutes.settings(TaskRoutes.photoViewer),
        pageBuilder: (context, animation, _) => PhotoViewerScreen(
          tripId: tripId,
          memories: List.of(memories),
          initialIndex: index,
        ),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MemoryModel memory,
  ) async {
    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete memory',
      body: const [
        'This removes the photo and anything written with it. It cannot be '
            'undone.',
      ],
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(tripMemoriesProvider(tripId).notifier).deleteMemory(memory.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.odyssey;
    final state = ref.watch(tripMemoriesProvider(tripId));

    if (state.isLoading && state.memories.isEmpty) {
      return const Column(
        children: [
          Skeleton(width: double.infinity, height: 236, radius: AppSizes.radiusTile),
          SizedBox(height: AppSizes.space10),
          Skeleton.tile(height: 113),
        ],
      );
    }

    if (state.error != null && state.memories.isEmpty) {
      return OdysseyErrorState(
        message: state.error!,
        onRetry: () => ref.read(tripMemoriesProvider(tripId).notifier).refresh(),
      );
    }

    if (state.memories.isEmpty) {
      return OdysseyEmptyState(
        message: 'No photos yet. The journal fills itself as you go.',
        actionLabel: 'Add a photo',
        onAction: () => _upload(context),
      );
    }

    final memories = state.memories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Memories',
              style: AppTypography.statCard.copyWith(color: t.ink),
            ),
            const SizedBox(width: AppSizes.space10),
            Text(
              '${memories.length}',
              style: AppTypography.legend.copyWith(
                fontWeight: FontWeight.w700,
                color: t.ink3,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space16),

        // The first tile is twice as tall as the rest, which is what gives the
        // wall its rhythm. Everything after it is a square in a two-up grid.
        if (memories.isNotEmpty)
          _MemoryTile(
            memory: memories.first,
            height: 236,
            onTap: () => _openViewer(context, memories, 0),
            onLongPress: () => _delete(context, ref, memories.first),
          ),

        if (memories.length > 1) ...[
          const SizedBox(height: AppSizes.space10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSizes.space10,
              mainAxisSpacing: AppSizes.space10,
              mainAxisExtent: 113,
            ),
            itemCount: memories.length,
            itemBuilder: (context, index) {
              if (index == memories.length - 1) {
                return DashedBox(
                  radius: AppSizes.radiusTile,
                  onTap: () => _upload(context),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+',
                        style: AppTypography.glyph.copyWith(
                          fontSize: 22,
                          color: t.ink2,
                        ),
                      ),
                      const SizedBox(height: AppSizes.space6),
                      Text(
                        'Add photo',
                        style: AppTypography.statLabel.copyWith(
                          fontWeight: FontWeight.w700,
                          color: t.ink3,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final memory = memories[index];
              return _MemoryTile(
                memory: memory,
                onTap: () => _openViewer(context, memories, index),
                onLongPress: () => _delete(context, ref, memory),
              );
            },
          ),
        ] else ...[
          const SizedBox(height: AppSizes.space10),
          PillButton(
            label: 'Add a photo',
            style: PillStyle.dashed,
            onPressed: () => _upload(context),
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ],
      ],
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({
    required this.memory,
    required this.onTap,
    required this.onLongPress,
    this.height,
  });

  final MemoryModel memory;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = memory.mediaItems.isNotEmpty
        ? (memory.mediaItems.first.thumbnailUrl ?? memory.mediaItems.first.url)
        : memory.photoUrl;

    final hasCaption = memory.caption != null && memory.caption!.isNotEmpty;

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppSizes.radiusTile),
      tint: false,
      child: PhotoSurface(
        imageUrl: url,
        seed: memory.id,
        height: height,
        radius: AppSizes.radiusTile,
        scrim: hasCaption,
        child: hasCaption
            ? Positioned(
                left: AppSizes.space12,
                right: AppSizes.space12,
                bottom: AppSizes.space12,
                child: Text(
                  memory.caption!,
                  style: AppTypography.rowMeta.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPhoto,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
      ),
    );
  }
}
