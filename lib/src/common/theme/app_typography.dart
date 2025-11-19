import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Odyssey Typography System
/// Headlines: Playfair Display (Serif, elegant)
/// Body: DM Sans (Clean, modern, readable)
class AppTypography {
  AppTypography._(); // Private constructor

  // Display Styles (Hero text)
  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.1,
  );

  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.15,
  );

  static TextStyle displaySmall = GoogleFonts.playfairDisplay(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  // Headline Styles (Section headers)
  static TextStyle headlineLarge = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  );

  static TextStyle headlineMedium = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle headlineSmall = GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.35,
  );

  // Title Styles (Card titles, list items)
  static TextStyle titleLarge = GoogleFonts.dmSans(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static TextStyle titleMedium = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static TextStyle titleSmall = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.45,
  );

  // Body Styles (Main content)
  static TextStyle bodyLarge = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    height: 1.6,
  );

  static TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.45,
  );

  // Label Styles (Buttons, tabs, chips)
  static TextStyle labelLarge = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static TextStyle labelMedium = GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.35,
  );

  static TextStyle labelSmall = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.3,
  );
}
