import 'package:flutter/material.dart';
import '../../../../common/animations/animation_constants.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../data/models/walkthrough_step_model.dart';
import 'spotlight_painter.dart';
import 'walkthrough_tooltip.dart';

/// Full-screen overlay that composes the spotlight painter and tooltip.
/// Handles animations and auto-positioning of the tooltip.
class WalkthroughOverlay extends StatefulWidget {
  final List<WalkthroughStep> steps;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const WalkthroughOverlay({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _glowController;
  late AnimationController _tooltipController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _tooltipSlideAnimation;
  late Animation<double> _tooltipFadeAnimation;

  Rect? _targetRect;
  bool _showAbove = false;

  @override
  void initState() {
    super.initState();

    // Overlay fade-in
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppAnimations.fadeIn,
    );

    // Spotlight breathing glow
    _glowController = AnimationController(
      duration: AppAnimations.pulse,
      vsync: this,
    )..repeat(reverse: true);

    // Tooltip slide-in on step change
    _tooltipController = AnimationController(
      duration: AppAnimations.medium,
      vsync: this,
    );
    _tooltipSlideAnimation = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _tooltipController,
        curve: AppAnimations.bouncyEnter,
      ),
    );
    _tooltipFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _tooltipController,
        curve: AppAnimations.fadeIn,
      ),
    );

    _fadeController.forward();
    _updateTargetRect();
  }

  @override
  void didUpdateWidget(WalkthroughOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _tooltipController.reset();
      _updateTargetRect();
    }
  }

  void _updateTargetRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final step = widget.steps[widget.currentIndex];
      final renderObject = step.targetKey.currentContext?.findRenderObject();

      if (renderObject is RenderBox && renderObject.hasSize) {
        final offset = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        final padding = step.targetPadding;

        setState(() {
          _targetRect = Rect.fromLTWH(
            offset.dx - padding.left,
            offset.dy - padding.top,
            size.width + padding.left + padding.right,
            size.height + padding.top + padding.bottom,
          );

          // Auto-position: if target is in top half, show tooltip below; otherwise above
          final screenHeight = MediaQuery.of(context).size.height;
          final targetCenter = offset.dy + size.height / 2;
          if (step.preferredPosition == TooltipPosition.above) {
            _showAbove = true;
          } else if (step.preferredPosition == TooltipPosition.below) {
            _showAbove = false;
          } else {
            _showAbove = targetCenter > screenHeight / 2;
          }
        });

        _tooltipController.forward();
      } else {
        // Target not found, skip to next step
        widget.onNext();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _glowController.dispose();
    _tooltipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) {
      return const SizedBox.shrink();
    }

    final step = widget.steps[widget.currentIndex];
    final screenSize = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          // Absorb taps outside tooltip to prevent interaction with underlying UI
          onTap: () {},
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Spotlight overlay
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  return CustomPaint(
                    size: screenSize,
                    painter: SpotlightPainter(
                      targetRect: _targetRect!,
                      borderRadius: AppSizes.radiusMd,
                      accentColor: step.accentColor,
                      glowProgress: _glowController.value,
                    ),
                  );
                },
              ),

              // Positioned tooltip
              AnimatedBuilder(
                animation: _tooltipController,
                builder: (context, child) {
                  final slideOffset = _showAbove
                      ? _tooltipSlideAnimation.value
                      : -_tooltipSlideAnimation.value;

                  return Positioned(
                    left: 0,
                    right: 0,
                    top: _showAbove ? null : _targetRect!.bottom + 12,
                    bottom: _showAbove
                        ? screenSize.height - _targetRect!.top + 12
                        : null,
                    child: Opacity(
                      opacity: _tooltipFadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, slideOffset),
                        child: Center(
                          child: WalkthroughTooltip(
                            step: step,
                            currentIndex: widget.currentIndex,
                            totalSteps: widget.steps.length,
                            isAbove: _showAbove,
                            onNext: widget.onNext,
                            onPrevious: widget.onPrevious,
                            onSkip: widget.onSkip,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
