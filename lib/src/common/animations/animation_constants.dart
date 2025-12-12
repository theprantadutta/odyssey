import 'package:flutter/material.dart';

/// Odyssey Animation System Constants
/// Vibrant & Playful - Bouncy, energetic animations inspired by Duolingo/Headspace
class AppAnimations {
  AppAnimations._(); // Private constructor

  // ============================================================
  // DURATIONS - Fast and snappy for playful feel
  // ============================================================

  /// Instant feedback for button presses
  static const Duration micro = Duration(milliseconds: 100);

  /// Quick transitions, hover effects
  static const Duration fast = Duration(milliseconds: 150);

  /// Standard animations, reveals
  static const Duration normal = Duration(milliseconds: 250);

  /// Medium complexity animations
  static const Duration medium = Duration(milliseconds: 350);

  /// Page transitions, complex animations
  static const Duration slow = Duration(milliseconds: 450);

  /// Dramatic reveals, celebrations
  static const Duration slower = Duration(milliseconds: 600);

  /// Very slow for ambient animations
  static const Duration dramatic = Duration(milliseconds: 800);

  // Page-specific durations
  static const Duration pageTransition = Duration(milliseconds: 400);
  static const Duration tabTransition = Duration(milliseconds: 250);
  static const Duration modalTransition = Duration(milliseconds: 300);

  // Loading/ambient durations
  static const Duration shimmer = Duration(milliseconds: 1500);
  static const Duration pulse = Duration(milliseconds: 2000);
  static const Duration orbit = Duration(milliseconds: 3000);
  static const Duration float = Duration(milliseconds: 4000);

  // Stagger delays
  static const Duration staggerDelay = Duration(milliseconds: 50);
  static const Duration listItemDelay = Duration(milliseconds: 80);
  static const Duration cascadeDelay = Duration(milliseconds: 100);

  // ============================================================
  // CURVES - Bouncy and playful
  // ============================================================

  // Button interactions - snappy bounce back
  static const Curve buttonPress = Curves.easeOutBack;
  static const Curve buttonRelease = Curves.elasticOut;

  // Card interactions
  static const Curve cardTap = Curves.easeOutCubic;
  static const Curve cardHover = Curves.easeInOutCubic;

  // Page transitions
  static const Curve pageEnter = Curves.easeOutQuart;
  static const Curve pageExit = Curves.easeInQuart;
  static const Curve sharedElement = Curves.easeInOutCubic;

  // Playful bounces (Duolingo-style)
  static const Curve bounce = Curves.elasticOut;
  static const Curve bouncyEnter = Curves.easeOutBack;
  static const Curve softBounce = Curves.easeOutQuint;
  static const Curve gentleBounce = Curves.easeOutQuad;

  // Smooth reveals
  static const Curve fadeIn = Curves.easeOut;
  static const Curve fadeOut = Curves.easeIn;
  static const Curve slideUp = Curves.easeOutCubic;
  static const Curve slideDown = Curves.easeInCubic;

  // Success/celebration
  static const Curve celebrate = Curves.elasticOut;
  static const Curve checkmark = Curves.easeOutBack;

  // Spring-like physics
  static const Curve spring = Curves.elasticOut;
  static const Curve springFast = Curves.easeOutBack;

  // ============================================================
  // SCALE VALUES
  // ============================================================

  /// Scale when button is pressed
  static const double pressedScale = 0.95;

  /// Scale when element is hovered
  static const double hoverScale = 1.02;

  /// Scale for bounce effect
  static const double bounceScale = 1.1;

  /// Scale for micro bounce
  static const double microBounce = 1.05;

  /// Scale for emphasis
  static const double emphasisScale = 1.15;

  // ============================================================
  // OFFSETS
  // ============================================================

  /// Distance for slide animations
  static const double slideDistance = 30.0;

  /// Distance for floating effect
  static const double floatDistance = 8.0;

  /// Distance for shake animations
  static const double shakeDistance = 10.0;

  /// Distance for subtle movement
  static const double subtleDistance = 4.0;

  // ============================================================
  // OPACITY VALUES
  // ============================================================

  /// Disabled state opacity
  static const double disabledOpacity = 0.5;

  /// Pressed state opacity
  static const double pressedOpacity = 0.8;

  /// Hover overlay opacity
  static const double hoverOverlay = 0.1;

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Check if user prefers reduced motion
  static bool prefersReducedMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get duration based on user preference (returns zero if reduced motion)
  static Duration getDuration(BuildContext context, Duration normal) {
    return prefersReducedMotion(context) ? Duration.zero : normal;
  }

  /// Get curve based on user preference (returns linear if reduced motion)
  static Curve getCurve(BuildContext context, Curve normal) {
    return prefersReducedMotion(context) ? Curves.linear : normal;
  }

  /// Calculate stagger delay for list items
  static Duration getStaggerDelay(int index, {int maxItems = 10}) {
    // Cap stagger at maxItems to prevent very long delays
    final cappedIndex = index.clamp(0, maxItems);
    return Duration(milliseconds: cappedIndex * staggerDelay.inMilliseconds);
  }

  /// Get interval for staggered animation within an AnimationController
  static Interval getStaggerInterval(int index, int totalItems) {
    const start = 0.0;
    const end = 0.6;
    final interval = (end - start) / totalItems;
    final itemStart = start + (index * interval);
    final itemEnd = itemStart + 0.4;
    return Interval(
      itemStart.clamp(0.0, 1.0),
      itemEnd.clamp(0.0, 1.0),
      curve: bouncyEnter,
    );
  }
}

/// Extension for easy Duration multiplication
extension DurationExtension on Duration {
  Duration operator *(double factor) {
    return Duration(milliseconds: (inMilliseconds * factor).round());
  }
}
