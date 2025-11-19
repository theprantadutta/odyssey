/// Odyssey Spacing & Sizing System
/// Consistent spacing, radius, and sizing values
class AppSizes {
  AppSizes._(); // Private constructor

  // Spacing Scale (8px base)
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

  // Border Radius (Rounded corners)
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radius2xl = 32.0;
  static const double radiusFull = 999.0; // Pill shape

  // Icon Sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  static const double icon2xl = 64.0;

  // Button Heights
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 48.0;
  static const double buttonHeightLg = 56.0;

  // Card Sizes
  static const double cardElevation = 0.0; // Flat design
  static const double cardBlur = 20.0; // Glassmorphism blur

  // Trip Card Dimensions
  static const double tripCardHeight = 280.0;
  static const double tripCardImageHeight = 180.0;

  // Activity Card Dimensions
  static const double activityCardHeight = 120.0;

  // Memory Pin Sizes (Map)
  static const double memoryPinSm = 40.0;
  static const double memoryPinMd = 56.0;
  static const double memoryPinLg = 72.0;

  // App Bar
  static const double appBarHeight = 64.0;
  static const double appBarElevation = 0.0;

  // Bottom Nav
  static const double bottomNavHeight = 72.0;

  // Parallax
  static const double parallaxMaxOffset = 200.0;
  static const double parallaxSpeed = 0.5;

  // Animation Durations (milliseconds)
  static const int animationFast = 200;
  static const int animationNormal = 300;
  static const int animationSlow = 500;
  static const int animationSlower = 800;

  // Screen Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // Z-Index Layers
  static const double zIndexBase = 0;
  static const double zIndexDropdown = 100;
  static const double zIndexModal = 200;
  static const double zIndexToast = 300;
}
