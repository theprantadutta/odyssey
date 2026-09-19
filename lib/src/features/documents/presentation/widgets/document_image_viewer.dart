import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../core/network/authenticated_media_fetch.dart';
import '../../../../core/utils/file_url_helper.dart';


/// Simple image viewer for document images
class DocumentImageViewer extends StatefulWidget {
  final List<String> images;
  final String title;

  const DocumentImageViewer({
    super.key,
    required this.images,
    required this.title,
  });

  @override
  State<DocumentImageViewer> createState() => _DocumentImageViewerState();
}

class _DocumentImageViewerState extends State<DocumentImageViewer> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.onSurface,
      appBar: AppBar(
        backgroundColor: colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              widget.title,
              style: AppTypography.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.images.length > 1)
              Text(
                '${_currentPage + 1} of ${widget.images.length}',
                style: AppTypography.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: FileUrlHelper.resolve(widget.images[index]),
                cacheManager: AuthenticatedMediaCacheManager.instance,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.lavenderDream),
                  ),
                ),
                errorWidget: (context, url, error) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      size: 64,
                      color: theme.hintColor,
                    ),
                    const SizedBox(height: AppSizes.space16),
                    Text(
                      'Failed to load image',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: widget.images.length > 1
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSizes.space16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentPage
                            ? AppColors.lavenderDream
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
