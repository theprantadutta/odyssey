import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../animation_constants.dart';

/// Animated button with scale, glow, and haptic feedback
/// Playful, bouncy interaction inspired by Duolingo
class AnimatedButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double height;

  const AnimatedButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = AppSizes.buttonHeightMd,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.micro,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AppAnimations.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.buttonPress,
    ));

    _glowAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
    _controller.forward();
    HapticFeedback.lightImpact();
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

  void _handleTap() {
    if (!_isEnabled) return;
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.backgroundColor ?? AppColors.goldenGlow;
    final fgColor =
        widget.foregroundColor ?? AppColors.snowWhite;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.buttonPress,
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.isOutlined
                    ? Colors.transparent
                    : (_isEnabled ? bgColor : AppColors.mutedGray.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: widget.isOutlined
                    ? Border.all(
                        color: _isEnabled ? bgColor : AppColors.mutedGray,
                        width: 2,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: widget.isOutlined || !_isEnabled
                        ? Colors.transparent
                        : bgColor.withValues(alpha: (0.4 * _glowAnimation.value).clamp(0.0, 1.0)),
                    blurRadius: widget.isOutlined || !_isEnabled
                        ? 0.0
                        : (20 * _glowAnimation.value).clamp(0.0, 20.0),
                    offset: widget.isOutlined || !_isEnabled
                        ? Offset.zero
                        : Offset(0, (8 * _glowAnimation.value).clamp(0.0, 8.0)),
                    spreadRadius: widget.isOutlined || !_isEnabled ? 0.0 : -4,
                  ),
                ],
              ),
              child: _buildContent(fgColor, bgColor),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(Color fgColor, Color bgColor) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(
              widget.isOutlined ? bgColor : fgColor,
            ),
          ),
        ),
      );
    }

    final textColor = widget.isOutlined
        ? (_isEnabled ? bgColor : AppColors.mutedGray)
        : (_isEnabled ? fgColor : AppColors.mutedGray);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.space24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              size: AppSizes.iconSm,
              color: textColor,
            ),
            const SizedBox(width: AppSizes.space8),
          ],
          Text(
            widget.text,
            style: AppTypography.button.copyWith(
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small animated icon button with circular shape
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.micro,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.buttonPress,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.softCream;
    final iconColor = widget.iconColor ?? AppColors.goldenGlow;

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          _controller.forward();
          HapticFeedback.selectionClick();
        }
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: AppSizes.mediumShadow,
              ),
              child: Icon(
                widget.icon,
                color: iconColor,
                size: widget.size * 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animated FAB with bounce effect
class AnimatedFAB extends StatefulWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool mini;

  const AnimatedFAB({
    super.key,
    required this.icon,
    this.label,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.mini = false,
  });

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.micro,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimations.buttonPress,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.goldenGlow;
    final fgColor = widget.foregroundColor ?? AppColors.snowWhite;

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          _controller.forward();
          HapticFeedback.mediumImpact();
        }
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.label != null ? AppSizes.space24 : AppSizes.space16,
                vertical: AppSizes.space16,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(
                  widget.label != null ? AppSizes.radiusLg : AppSizes.radiusFull,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                    spreadRadius: -2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: fgColor,
                    size: widget.mini ? 20 : 24,
                  ),
                  if (widget.label != null) ...[
                    const SizedBox(width: AppSizes.space8),
                    Text(
                      widget.label!,
                      style: AppTypography.labelLarge.copyWith(
                        color: fgColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
