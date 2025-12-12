import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Odyssey Typography System - Vibrant & Playful
/// Headlines: Nunito (Rounded, friendly, approachable)
/// Body: Inter (Clean, modern, highly readable)
class AppTypography {
  AppTypography._(); // Private constructor

  // ============================================================
  // DISPLAY STYLES (Hero text, splash screens)
  // Using Nunito ExtraBold for maximum impact
  // ============================================================
  static TextStyle displayLarge = GoogleFonts.nunito(
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static TextStyle displayMedium = GoogleFonts.nunito(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.15,
  );

  static TextStyle displaySmall = GoogleFonts.nunito(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.2,
  );

  // ============================================================
  // HEADLINE STYLES (Section headers, screen titles)
  // Using Nunito Bold for friendly emphasis
  // ============================================================
  static TextStyle headlineLarge = GoogleFonts.nunito(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  static TextStyle headlineMedium = GoogleFonts.nunito(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle headlineSmall = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  // ============================================================
  // TITLE STYLES (Card titles, list items, subtitles)
  // Using Inter SemiBold for clean readability
  // ============================================================
  static TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.45,
  );

  // ============================================================
  // BODY STYLES (Main content, descriptions, paragraphs)
  // Using Inter Regular for optimal readability
  // ============================================================
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.6,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.45,
  );

  // ============================================================
  // LABEL STYLES (Buttons, tabs, chips, badges)
  // Using Inter SemiBold for UI elements
  // ============================================================
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.35,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.3,
  );

  // ============================================================
  // SPECIAL STYLES
  // ============================================================

  /// App logo/brand text - extra bold and playful
  static TextStyle brandLarge = GoogleFonts.nunito(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Button text - slightly bolder for emphasis
  static TextStyle button = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.2,
  );

  /// Caption text - for timestamps, metadata
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.3,
  );

  /// Overline text - for category labels
  static TextStyle overline = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    height: 1.5,
  );
}
