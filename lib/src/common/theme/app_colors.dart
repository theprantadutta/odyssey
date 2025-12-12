import 'package:flutter/material.dart';

/// Odyssey Color Palette - Vibrant & Playful
/// Inspired by Duolingo and Headspace - friendly, approachable, fun!
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ============================================================
  // PRIMARY COLORS - Warm Gold (Hero Color)
  // ============================================================
  /// Main gold - primary buttons, CTAs, highlights (softer, warmer)
  static const Color sunnyYellow = Color(0xFFF5B800);

  /// Hover/emphasis states (deeper gold)
  static const Color goldenGlow = Color(0xFFD9A404);

  /// Light backgrounds, subtle highlights (warm cream)
  static const Color lemonLight = Color(0xFFFFF9E6);

  // Legacy aliases for backward compatibility
  static const Color sunsetGold = sunnyYellow;
  static const Color softGold = goldenGlow;
  static const Color paleGold = lemonLight;

  // ============================================================
  // SECONDARY COLORS - Playful Companions
  // ============================================================
  /// Secondary accent, notifications, alerts
  static const Color coralBurst = Color(0xFFFF6B6B);

  /// Success states, progress, positive actions
  static const Color oceanTeal = Color(0xFF4ECDC4);

  /// Tertiary accent, badges, tags
  static const Color lavenderDream = Color(0xFFA78BFA);

  /// Information, links, secondary actions
  static const Color skyBlue = Color(0xFF60A5FA);

  // Legacy aliases
  static const Color coralPink = coralBurst;
  static const Color mintGreen = oceanTeal;

  // ============================================================
  // BACKGROUND COLORS
  // ============================================================
  /// Primary background - pure white
  static const Color snowWhite = Color(0xFFFFFFFF);

  /// Secondary background - subtle gray
  static const Color cloudGray = Color(0xFFF8FAFC);

  /// Yellow-tinted cards, warm highlights
  static const Color softCream = Color(0xFFFEFCE8);

  /// Input backgrounds, disabled states
  static const Color warmGray = Color(0xFFF1F5F9);

  // Legacy aliases
  static const Color frostedWhite = cloudGray;

  // ============================================================
  // TEXT COLORS
  // ============================================================
  /// Primary text - dark charcoal
  static const Color charcoal = Color(0xFF1E293B);

  /// Secondary text - slate gray
  static const Color slate = Color(0xFF64748B);

  /// Placeholder, disabled, tertiary text
  static const Color mutedGray = Color(0xFF94A3B8);

  /// Text on dark/colored backgrounds
  static const Color pureWhite = Color(0xFFFFFFFF);

  // Legacy aliases
  static const Color textPrimary = charcoal;
  static const Color textSecondary = slate;
  static const Color textTertiary = mutedGray;
  static const Color textOnDark = pureWhite;

  // Legacy dark theme colors (kept for compatibility, may be removed)
  static const Color midnightBlue = Color(0xFF0A1E2F);
  static const Color deepNavy = Color(0xFF152638);
  static const Color navyAccent = Color(0xFF1A2F42);

  // ============================================================
  // SEMANTIC COLORS
  // ============================================================
  /// Success states - vibrant green
  static const Color success = Color(0xFF22C55E);

  /// Error states - bright red
  static const Color error = Color(0xFFEF4444);

  /// Warning states - orange
  static const Color warning = Color(0xFFF97316);

  /// Info states - blue
  static const Color info = Color(0xFF3B82F6);

  // ============================================================
  // SURFACE COLORS (for glassmorphism alternatives)
  // ============================================================
  static const Color glassSurface = Color(0x40FFFFFF);
  static const Color darkGlassSurface = Color(0x40000000);

  // ============================================================
  // GRADIENTS
  // ============================================================

  /// Primary gradient - sunny yellow energy
  static const LinearGradient sunshineGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunnyYellow, goldenGlow],
  );

  /// Playful multi-color gradient
  static const LinearGradient playfulGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunnyYellow, coralBurst, oceanTeal],
  );

  /// Soft background gradient - cream to white
  static const LinearGradient softBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [softCream, snowWhite],
  );

  /// Card highlight gradient
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [snowWhite, cloudGray],
  );

  // Legacy gradients (kept for compatibility)
  static const LinearGradient primaryGradient = sunshineGradient;
  static const LinearGradient goldGradient = sunshineGradient;
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x80FFFFFF), Color(0x40FFFFFF)],
  );

  // ============================================================
  // SHADOW COLORS
  // ============================================================
  /// Soft shadow for cards (7% black)
  static Color get softShadow => Colors.black.withValues(alpha: 0.07);

  /// Medium shadow for elevated elements (10% black)
  static Color get mediumShadow => Colors.black.withValues(alpha: 0.10);

  /// Yellow glow for primary buttons (40% yellow)
  static Color get yellowGlow => sunnyYellow.withValues(alpha: 0.4);

  // ============================================================
  // STATUS COLORS (for badges)
  // ============================================================
  /// Planned status - yellow
  static const Color statusPlanned = sunnyYellow;
  static const Color statusPlannedBg = lemonLight;

  /// Ongoing status - teal
  static const Color statusOngoing = oceanTeal;
  static const Color statusOngoingBg = Color(0xFFE0F7F4);

  /// Completed status - green
  static const Color statusCompleted = success;
  static const Color statusCompletedBg = Color(0xFFDCFCE7);
}
