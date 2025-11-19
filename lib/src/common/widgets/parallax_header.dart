import 'package:flutter/material.dart';
import '../theme/app_sizes.dart';

/// Cinematic parallax header with smooth scrolling effect
///
/// Usage:
/// ```dart
/// CustomScrollView(
///   slivers: [
///     ParallaxHeader(
///       imageUrl: 'https://...',
///       height: 300,
///       child: Text('Overlay content'),
///     ),
///     // ... other slivers
///   ],
/// )
/// ```
class ParallaxHeader extends StatelessWidget {
  final String? imageUrl;
  final String? imageAsset;
  final double height;
  final Widget? child;
  final Gradient? gradient;
  final double parallaxSpeed;

  const ParallaxHeader({
    super.key,
    this.imageUrl,
    this.imageAsset,
    required this.height,
    this.child,
    this.gradient,
    this.parallaxSpeed = AppSizes.parallaxSpeed,
  }) : assert(imageUrl != null || imageAsset != null,
            'Either imageUrl or imageAsset must be provided');

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: height,
      pinned: false,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Parallax Image
            _buildParallaxImage(),

            // Gradient Overlay
            if (gradient != null)
              Container(
                decoration: BoxDecoration(gradient: gradient),
              ),

            // Custom child overlay
            if (child != null)
              Positioned.fill(
                child: child!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParallaxImage() {
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 48),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );
    } else {
      return Image.asset(
        imageAsset!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 48),
          );
        },
      );
    }
  }
}

/// Simpler parallax container for list items
class ParallaxContainer extends StatelessWidget {
  final Widget child;
  final String? imageUrl;
  final String? imageAsset;
  final double height;
  final Gradient? gradient;
  final BorderRadius? borderRadius;

  const ParallaxContainer({
    super.key,
    required this.child,
    this.imageUrl,
    this.imageAsset,
    required this.height,
    this.gradient,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(AppSizes.radiusLg),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            if (imageUrl != null || imageAsset != null)
              _buildBackgroundImage(),

            // Gradient overlay
            if (gradient != null)
              Container(
                decoration: BoxDecoration(gradient: gradient),
              ),

            // Content
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundImage() {
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.grey[300]);
        },
      );
    } else if (imageAsset != null) {
      return Image.asset(
        imageAsset!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.grey[300]);
        },
      );
    }
    return const SizedBox.shrink();
  }
}

/// Flow delegate for parallax scrolling effect
class ParallaxFlowDelegate extends FlowDelegate {
  final ScrollableState scrollable;
  final BuildContext listItemContext;
  final GlobalKey backgroundImageKey;

  ParallaxFlowDelegate({
    required this.scrollable,
    required this.listItemContext,
    required this.backgroundImageKey,
  }) : super(repaint: scrollable.position);

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    return BoxConstraints.tightFor(
      width: constraints.maxWidth,
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox;
    final listItemBox = listItemContext.findRenderObject() as RenderBox;
    final listItemOffset = listItemBox.localToGlobal(
      listItemBox.size.centerLeft(Offset.zero),
      ancestor: scrollableBox,
    );

    final viewportDimension = scrollable.position.viewportDimension;
    final scrollFraction =
        (listItemOffset.dy / viewportDimension).clamp(0.0, 1.0);

    final verticalAlignment = Alignment(0.0, scrollFraction * 2 - 1);

    final backgroundSize =
        (backgroundImageKey.currentContext!.findRenderObject() as RenderBox)
            .size;
    final listItemSize = context.size;
    final childRect = verticalAlignment.inscribe(
      backgroundSize,
      Offset.zero & listItemSize,
    );

    context.paintChild(
      0,
      transform: Transform.translate(
        offset: Offset(0.0, childRect.top),
      ).transform,
    );
  }

  @override
  bool shouldRepaint(ParallaxFlowDelegate oldDelegate) {
    return scrollable != oldDelegate.scrollable ||
        listItemContext != oldDelegate.listItemContext ||
        backgroundImageKey != oldDelegate.backgroundImageKey;
  }
}
