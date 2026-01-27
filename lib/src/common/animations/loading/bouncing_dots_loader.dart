import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../animation_constants.dart';

/// Playful bouncing dots loader inspired by Duolingo
/// Three dots that bounce in sequence
class BouncingDotsLoader extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double spacing;

  const BouncingDotsLoader({
    super.key,
    this.color,
    this.dotSize = 10,
    this.spacing = 4,
  });

  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? AppColors.sunnyYellow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Each dot bounces at different times
            final delay = index * 0.15;
            final value = (_controller.value - delay).clamp(0.0, 1.0);

            // Create bounce effect using sine wave
            final bounce = math.sin(value * math.pi * 2) * 0.5 + 0.5;
            final offset = bounce * -widget.dotSize;
            final scale = 1.0 + (bounce * 0.2);

            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.3 * bounce),
                          blurRadius: 8,
                          offset: Offset(0, 4 * bounce),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Pulsing icon loader with travel theme
class PulsingIconLoader extends StatefulWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const PulsingIconLoader({
    super.key,
    this.icon = Icons.explore,
    this.size = 48,
    this.color,
  });

  @override
  State<PulsingIconLoader> createState() => _PulsingIconLoaderState();
}

class _PulsingIconLoaderState extends State<PulsingIconLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
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
    final iconColor = widget.color ?? AppColors.sunnyYellow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.all(widget.size * 0.25),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: widget.size,
                color: iconColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Orbital loader with airplane circling a globe
class OrbitalLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const OrbitalLoader({
    super.key,
    this.size = 60,
    this.color,
  });

  @override
  State<OrbitalLoader> createState() => _OrbitalLoaderState();
}

class _OrbitalLoaderState extends State<OrbitalLoader>
    with TickerProviderStateMixin {
  late AnimationController _orbitController;
  late AnimationController _globeController;

  @override
  void initState() {
    super.initState();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _globeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _globeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.sunnyYellow;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center globe
          AnimatedBuilder(
            animation: _globeController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _globeController.value * 2 * math.pi,
                child: Icon(
                  Icons.public,
                  size: widget.size * 0.4,
                  color: color.withValues(alpha: 0.3),
                ),
              );
            },
          ),

          // Orbit path
          Container(
            width: widget.size * 0.85,
            height: widget.size * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.15),
                width: 2,
                strokeAlign: BorderSide.strokeAlignCenter,
              ),
            ),
          ),

          // Orbiting airplane
          AnimatedBuilder(
            animation: _orbitController,
            builder: (context, child) {
              final angle = _orbitController.value * 2 * math.pi;
              final x = math.cos(angle) * widget.size * 0.35;
              final y = math.sin(angle) * widget.size * 0.35;

              return Transform.translate(
                offset: Offset(x, y),
                child: Transform.rotate(
                  angle: angle + math.pi / 2,
                  child: Icon(
                    Icons.airplanemode_active,
                    size: widget.size * 0.2,
                    color: color,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Simple spinning loader
class SpinningLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const SpinningLoader({
    super.key,
    this.size = 32,
    this.color,
    this.strokeWidth = 3,
  });

  @override
  State<SpinningLoader> createState() => _SpinningLoaderState();
}

class _SpinningLoaderState extends State<SpinningLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CircularProgressIndicator(
        strokeWidth: widget.strokeWidth,
        valueColor: AlwaysStoppedAnimation(
          widget.color ?? AppColors.sunnyYellow,
        ),
        backgroundColor: AppColors.lemonLight,
      ),
    );
  }
}

/// Full-screen loading overlay with optional message
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final Color? backgroundColor;
  final Widget? loadingWidget;

  const LoadingOverlay({
    super.key,
    required this.child,
    this.isLoading = false,
    this.message,
    this.backgroundColor,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        AnimatedSwitcher(
          duration: AppAnimations.fast,
          child: isLoading
              ? Positioned.fill(
                  key: const ValueKey('loading_overlay'),
                  child: Container(
                    color: backgroundColor ??
                        (isDark
                            ? Colors.black.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.85)),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          loadingWidget ?? const OrbitalLoader(size: 72),
                          if (message != null) ...[
                            const SizedBox(height: 24),
                            Text(
                              message!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }
}
