import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';

/// Premium glassmorphism container with frosted glass effect
///
/// Usage:
/// ```dart
/// GlassContainer(
///   child: Text('Content'),
///   blur: 20.0,
///   opacity: 0.25,
/// )
/// ```
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final Color? color;
  final EdgeInsets? padding;
  final Border? border;
  final Gradient? gradient;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = AppSizes.cardBlur,
    this.opacity = 0.25,
    this.borderRadius = AppSizes.radiusLg,
    this.color,
    this.padding,
    this.border,
    this.gradient,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
        ),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(opacity),
            gradient: gradient,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ??
                Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Dark variant of glass container
class DarkGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  const DarkGlassContainer({
    super.key,
    required this.child,
    this.blur = AppSizes.cardBlur,
    this.opacity = 0.4,
    this.borderRadius = AppSizes.radiusLg,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      blur: blur,
      opacity: opacity,
      borderRadius: borderRadius,
      color: AppColors.darkGlassSurface,
      padding: padding,
      width: width,
      height: height,
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      child: child,
    );
  }
}

/// Gradient glass container with gold accent
class GoldGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  const GoldGlassContainer({
    super.key,
    required this.child,
    this.blur = AppSizes.cardBlur,
    this.borderRadius = AppSizes.radiusLg,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
        ),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.sunsetGold.withOpacity(0.2),
                AppColors.softGold.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppColors.sunsetGold.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
