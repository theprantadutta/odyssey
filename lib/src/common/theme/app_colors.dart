import 'package:flutter/material.dart';

/// Odyssey Color Palette - Cinematic & Premium
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary Colors - Deep & Sophisticated
  static const Color midnightBlue = Color(0xFF0A1E2F);
  static const Color deepNavy = Color(0xFF152638);
  static const Color navyAccent = Color(0xFF1A2F42);

  // Accent Colors - Sunset Gold
  static const Color sunsetGold = Color(0xFFD4AF37);
  static const Color softGold = Color(0xFFE8D7A0);
  static const Color paleGold = Color(0xFFF5EDD6);

  // Complementary Accent Colors
  static const Color coralPink = Color(0xFFFF6B6B);
  static const Color mintGreen = Color(0xFF4ECDC4);

  // Surface Colors
  static const Color frostedWhite = Color(0xFFF8F9FA);
  static const Color glassSurface = Color(0x40FFFFFF); // 25% opacity
  static const Color darkGlassSurface = Color(0x40000000); // 25% dark

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFF9FAFB);

  // Background Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnightBlue, deepNavy],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunsetGold, softGold],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x80FFFFFF),
      Color(0x40FFFFFF),
    ],
  );
}
