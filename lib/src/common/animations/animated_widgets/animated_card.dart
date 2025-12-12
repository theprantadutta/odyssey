import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../animation_constants.dart';

/// Animated card with press, hover, and tap animations
/// Includes stagger animation support for lists
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final int? staggerIndex;
  final bool enableShadow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const AnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.backgroundColor,
    this.staggerIndex,
    this.enableShadow = true,
    this.padding,
    this.margin,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.fast,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppAnimations.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.cardTap,
    ));

    _elevationAnimation = Tween<double>(
      begin: 1.0,
      end: 0.5,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius =
        widget.borderRadius ?? BorderRadius.circular(AppSizes.radiusLg);

    Widget card = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: widget.margin,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppColors.snowWhite,
                borderRadius: borderRadius,
                boxShadow: widget.enableShadow
                    ? [
                        BoxShadow(
                          color: AppColors.softShadow,
                          blurRadius: 24 * _elevationAnimation.value,
                          offset: Offset(0, 8 * _elevationAnimation.value),
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: borderRadius,
                child: widget.padding != null
                    ? Padding(
                        padding: widget.padding!,
                        child: widget.child,
                      )
                    : widget.child,
              ),
            ),
          );
        },
      ),
    );

    // Apply stagger animation if index provided
    if (widget.staggerIndex != null) {
      card = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: AppAnimations.normal,
        curve: AppAnimations.bouncyEnter,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }
}

/// Animated list item that fades and slides in with stagger effect
class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: AppAnimations.bouncyEnter,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// A card that subtly floats up and down
class FloatingCard extends StatefulWidget {
  final Widget child;
  final double floatHeight;
  final Duration duration;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const FloatingCard({
    super.key,
    required this.child,
    this.floatHeight = 4.0,
    this.duration = const Duration(seconds: 3),
    this.borderRadius,
    this.backgroundColor,
    this.padding,
  });

  @override
  State<FloatingCard> createState() => _FloatingCardState();
}

class _FloatingCardState extends State<FloatingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: 0,
      end: widget.floatHeight,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_floatAnimation.value),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? AppColors.snowWhite,
              borderRadius:
                  widget.borderRadius ?? BorderRadius.circular(AppSizes.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.softShadow,
                  blurRadius: 24 + (_floatAnimation.value * 2),
                  offset: Offset(0, 8 + _floatAnimation.value),
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// A container that pulses subtly to draw attention
class PulsingContainer extends StatefulWidget {
  final Widget child;
  final Color? pulseColor;
  final Duration duration;
  final double maxScale;

  const PulsingContainer({
    super.key,
    required this.child,
    this.pulseColor,
    this.duration = const Duration(milliseconds: 1500),
    this.maxScale = 1.05,
  });

  @override
  State<PulsingContainer> createState() => _PulsingContainerState();
}

class _PulsingContainerState extends State<PulsingContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        );
      },
    );
  }
}
