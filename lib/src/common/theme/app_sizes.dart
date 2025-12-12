import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Odyssey Spacing & Sizing System - Vibrant & Playful
/// Consistent spacing, radius, sizing, and shadow values
class AppSizes {
  AppSizes._(); // Private constructor

  // ============================================================
  // SPACING SCALE (8px base)
  // ============================================================
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;

  // ============================================================
  // BORDER RADIUS (Increased for playful, rounded feel)
  // ============================================================
  static const double radiusXs = 8.0;   // was 4.0
  static const double radiusSm = 12.0;  // was 8.0
  static const double radiusMd = 16.0;  // was 12.0
  static const double radiusLg = 24.0;  // was 16.0
  static const double radiusXl = 32.0;  // was 24.0
  static const double radius2xl = 40.0; // was 32.0
  static const double radiusFull = 999.0; // Pill shape

  // ============================================================
  // ICON SIZES
  // ============================================================
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double icon2xl = 64.0;

  // ============================================================
  // BUTTON HEIGHTS
  // ============================================================
  static const double buttonHeightSm = 40.0;  // was 36.0
  static const double buttonHeightMd = 52.0;  // was 48.0
  static const double buttonHeightLg = 60.0;  // was 56.0

  // ============================================================
  // CARD SIZES
  // ============================================================
  static const double cardElevation = 0.0; // Using custom shadows instead
  static const double cardBlur = 20.0; // For glassmorphism (deprecated)

  // ============================================================
  // TRIP CARD DIMENSIONS
  // ============================================================
  static const double tripCardHeight = 260.0;  // slightly reduced
  static const double tripCardImageHeight = 160.0;  // slightly reduced

  // ============================================================
  // ACTIVITY CARD DIMENSIONS
  // ============================================================
  static const double activityCardHeight = 100.0;  // was 120.0

  // ============================================================
  // MEMORY PIN SIZES (Map)
  // ============================================================
  static const double memoryPinSm = 40.0;
  static const double memoryPinMd = 56.0;
  static const double memoryPinLg = 72.0;

  // ============================================================
  // APP BAR
  // ============================================================
  static const double appBarHeight = 64.0;
  static const double appBarElevation = 0.0;

  // ============================================================
  // BOTTOM NAV
  // ============================================================
  static const double bottomNavHeight = 72.0;

  // ============================================================
  // PARALLAX
  // ============================================================
  static const double parallaxMaxOffset = 200.0;
  static const double parallaxSpeed = 0.5;

  // ============================================================
  // ANIMATION DURATIONS (milliseconds) - Playful timing
  // ============================================================
  static const int animationMicro = 100;    // Instant feedback
  static const int animationFast = 150;     // was 200
  static const int animationNormal = 250;   // was 300
  static const int animationMedium = 350;   // NEW
  static const int animationSlow = 450;     // was 500
  static const int animationSlower = 600;   // was 800

  // Duration objects for convenience
  static const Duration durationMicro = Duration(milliseconds: animationMicro);
  static const Duration durationFast = Duration(milliseconds: animationFast);
  static const Duration durationNormal = Duration(milliseconds: animationNormal);
  static const Duration durationMedium = Duration(milliseconds: animationMedium);
  static const Duration durationSlow = Duration(milliseconds: animationSlow);
  static const Duration durationSlower = Duration(milliseconds: animationSlower);

  // ============================================================
  // SCREEN BREAKPOINTS
  // ============================================================
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // ============================================================
  // Z-INDEX LAYERS
  // ============================================================
  static const double zIndexBase = 0;
  static const double zIndexDropdown = 100;
  static const double zIndexModal = 200;
  static const double zIndexToast = 300;

  // ============================================================
  // BOX SHADOWS - Soft and playful
  // ============================================================

  /// Soft shadow for cards - subtle elevation
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.softShadow,
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  /// Medium shadow for elevated elements
  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: AppColors.mediumShadow,
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ];

  /// Strong shadow for modals, FABs
  static List<BoxShadow> get strongShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 32,
          offset: const Offset(0, 12),
          spreadRadius: 0,
        ),
      ];

  /// Yellow glow for primary buttons
  static List<BoxShadow> get yellowGlowShadow => [
        BoxShadow(
          color: AppColors.yellowGlow,
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];

  /// Pressed button shadow (reduced)
  static List<BoxShadow> get pressedShadow => [
        BoxShadow(
          color: AppColors.softShadow,
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ];

  // ============================================================
  // INPUT FIELD SIZES
  // ============================================================
  static const double inputHeight = 56.0;
  static const double inputBorderWidth = 1.5;
  static const double inputFocusBorderWidth = 2.0;

  // ============================================================
  // AVATAR SIZES
  // ============================================================
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double avatarXl = 96.0;

  // ============================================================
  // BADGE SIZES
  // ============================================================
  static const double badgeHeight = 24.0;
  static const double badgePadding = 8.0;

  // ============================================================
  // TOUCH TARGETS
  // ============================================================
  static const double minTouchTarget = 48.0;
}
