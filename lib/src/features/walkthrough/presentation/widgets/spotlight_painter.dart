import 'package:flutter/material.dart';

/// CustomPainter that draws a dark overlay with a rounded cutout (spotlight)
/// around the target widget, plus an animated accent-color glow border.
class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double borderRadius;
  final Color accentColor;
  final double glowProgress; // 0.0 - 1.0 for breathing animation
  final double overlayOpacity;

  SpotlightPainter({
    required this.targetRect,
    this.borderRadius = 16.0,
    required this.accentColor,
    this.glowProgress = 0.0,
    this.overlayOpacity = 0.7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Full screen path
    final fullScreenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Hole path (rounded rect around target)
    final holePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(targetRect, Radius.circular(borderRadius)),
      );

    // Combine: full screen minus hole = dark overlay with cutout
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      holePath,
    );

    // Draw the dark overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: overlayOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw the glow border around the cutout
    final glowOpacity = 0.3 + (0.5 * glowProgress); // 0.3 to 0.8
    final glowWidth = 2.0 + (2.0 * glowProgress); // 2 to 4
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + (4 * glowProgress));

    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, Radius.circular(borderRadius)),
      glowPaint,
    );

    // Draw a solid border on top of the glow
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6 + (0.3 * glowProgress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.glowProgress != glowProgress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.overlayOpacity != overlayOpacity;
  }
}
