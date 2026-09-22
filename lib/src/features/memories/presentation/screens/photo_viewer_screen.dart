import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/utils/trip_format.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/network/authenticated_media_fetch.dart';
import '../../../../core/utils/file_url_helper.dart';
import '../../data/models/memory_model.dart';
import '../providers/memories_provider.dart';

/// A memory, full screen, with the chrome tucked away until you tap.
///
/// This screen is always dark regardless of theme: it is a photograph filling
/// the display, and a paper-white surround would fight every image on it.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.tripId,
    required this.memories,
    required this.initialIndex,
  });

  final String tripId;
  final List<MemoryModel> memories;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );

  late int _currentIndex = widget.initialIndex;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _delete() async {
    final memory = widget.memories[_currentIndex];

    final confirmed = await showOdysseyConfirm(
      context: context,
      title: 'Delete memory',
      body: const [
        'This removes the photo and anything written with it. It cannot be '
            'undone.',
      ],
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    try {
      await ref
          .read(tripMemoriesProvider(widget.tripId).notifier)
          .deleteMemory(memory.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showOdysseyError(context, 'Could not delete that.', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = widget.memories[_currentIndex];
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final meta = [
      if (memory.location != null && memory.location!.isNotEmpty)
        memory.location!,
      if (memory.takenAt != null)
        TripFormat.longDate(DateTime.tryParse(memory.takenAt!)),
    ].join(' · ');

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showChrome = !_showChrome);
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.memories.length,
              onPageChanged: (index) {
                HapticFeedback.selectionClick();
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) =>
                  _PhotoPage(memory: widget.memories[index]),
            ),
          ),

          AnimatedOpacity(
            opacity: _showChrome ? 1 : 0,
            duration: AppSizes.durationState,
            child: IgnorePointer(
              ignoring: !_showChrome,
              child: Stack(
                children: [
                  Positioned(
                    left: AppSizes.screenPadding,
                    right: AppSizes.screenPadding,
                    top: topInset + AppSizes.space14,
                    child: Row(
                      children: [
                        CircleButton(
                          glyph: '✕',
                          style: CircleStyle.glass,
                          onPressed: () => Navigator.of(context).pop(),
                          semanticLabel: 'Close',
                        ),
                        const Spacer(),
                        if (widget.memories.length > 1)
                          PhotoPill(
                            label:
                                '${_currentIndex + 1} of '
                                '${widget.memories.length}',
                            showDot: false,
                          ),
                        const SizedBox(width: AppSizes.space8),
                        CircleButton(
                          icon: Icons.delete_outline_rounded,
                          style: CircleStyle.glass,
                          onPressed: _delete,
                          semanticLabel: 'Delete memory',
                        ),
                      ],
                    ),
                  ),

                  if ((memory.caption?.isNotEmpty ?? false) ||
                      meta.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          AppSizes.screenPadding,
                          AppSizes.space40,
                          AppSizes.screenPadding,
                          bottomInset + AppSizes.space24,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x000A0B0D),
                              Color(0xD90A0B0D),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (memory.caption?.isNotEmpty ?? false)
                              Text(
                                memory.caption!,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.onPhoto,
                                ),
                              ),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: AppSizes.space8),
                              Text(
                                meta,
                                style: AppTypography.rowMeta.copyWith(
                                  color: AppColors.onPhoto2,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One page: the image, pinch to zoom and double-tap to snap between fit and
/// 2.5×.
class _PhotoPage extends StatefulWidget {
  const _PhotoPage({required this.memory});

  final MemoryModel memory;

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..addListener(() {
    final animation = _animation;
    if (animation != null) _transformationController.value = animation.value;
  });

  Animation<Matrix4>? _animation;

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details) {
    HapticFeedback.mediumImpact();

    final Matrix4 target;
    if (_transformationController.value != Matrix4.identity()) {
      target = Matrix4.identity();
    } else {
      final position = details.localPosition;
      target = Matrix4.identity()
        ..translateByDouble(-position.dx, -position.dy, 0, 0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0)
        ..translateByDouble(position.dx, position.dy, 0, 0);
    }

    _animation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOut,
          ),
        );
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'memory-${widget.memory.id}',
      child: GestureDetector(
        onDoubleTapDown: _onDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: FileUrlHelper.resolve(widget.memory.photoUrl),
              // Private files come from our API, which authorizes each
              // request. The cache manager attaches the current token and
              // refreshes it on a 401; headers captured at build time go stale
              // within fifteen minutes.
              cacheManager: AuthenticatedMediaCacheManager.instance,
              fit: BoxFit.contain,
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    size: 32,
                    color: AppColors.onPhoto2,
                  ),
                  const SizedBox(height: AppSizes.space12),
                  Text(
                    'That image would not load',
                    style: AppTypography.rowMeta.copyWith(
                      color: AppColors.onPhoto2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
