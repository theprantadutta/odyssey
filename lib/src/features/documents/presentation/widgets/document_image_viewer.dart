import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../../../../core/network/authenticated_media_fetch.dart';
import '../../../../core/utils/file_url_helper.dart';

/// A document's images, full screen.
///
/// Dark in both themes for the same reason the photo and PDF viewers are: the
/// content is a rectangle of someone else's white, and a paper surround leaves
/// no edge between it and the app.
class DocumentImageViewer extends StatefulWidget {
  const DocumentImageViewer({
    super.key,
    required this.images,
    required this.title,
  });

  final List<String> images;
  final String title;

  @override
  State<DocumentImageViewer> createState() => _DocumentImageViewerState();
}

class _DocumentImageViewerState extends State<DocumentImageViewer> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: FileUrlHelper.resolve(widget.images[index]),
                    // Private files come from our API, which authorizes each
                    // request; the manager attaches the current token and
                    // refreshes it on a 401.
                    cacheManager: AuthenticatedMediaCacheManager.instance,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => Text(
                      'That page would not load',
                      style: AppTypography.rowMeta.copyWith(
                        color: AppColors.onPhoto2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

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
                const SizedBox(width: AppSizes.space12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onPhoto,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + AppSizes.space20,
              child: Center(
                child: PhotoPill(
                  label: '${_currentPage + 1} of ${widget.images.length}',
                  showDot: false,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
