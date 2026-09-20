import 'package:flutter/material.dart';

/// Odyssey 2.0 metrics — spacing, radii, and the handful of fixed dimensions
/// the design pins exactly.
///
/// The design system leans on a small set of repeated numbers. Where a value
/// only appears once (a 320px hero, a 470px map region) it lives at the call
/// site rather than here; this file holds what genuinely recurs.
class AppSizes {
  AppSizes._();

  // ============================================================
  // SPACING
  // ============================================================
  // Base scale: 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18 / 20 / 22 / 24 / 26 / 44.

  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space18 = 18.0;
  static const double space20 = 20.0;
  static const double space22 = 22.0;
  static const double space24 = 24.0;
  static const double space26 = 26.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space44 = 44.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;
  static const double space80 = 80.0;

  // ============================================================
  // SCREEN LAYOUT
  // ============================================================

  /// Standard horizontal screen padding.
  static const double screenPadding = 20.0;

  /// Horizontal padding on auth and onboarding screens, which sit wider.
  static const double authPadding = 24.0;

  /// First content top padding. Content starts *under* the overlaid status
  /// bar, so this is measured from the top of the screen, not from the inset.
  static const double contentTop = 62.0;

  /// Bottom padding on scrolling content.
  static const double scrollBottom = 44.0;

  /// Spacer a scrolling screen adds so its last row clears the floating nav.
  static const double navSpacer = 130.0;

  /// The floating nav's own outer padding: `0 20px 28px`.
  static const double navBottomInset = 28.0;

  // ============================================================
  // RADII
  // ============================================================

  /// Fully rounded — buttons, chips, tabs, nav, progress bars, pills.
  static const double radiusFull = 999.0;

  /// Hero photo card, bento tile, stat tile.
  static const double radiusHero = 30.0;

  /// The larger hero — home next-trip card.
  static const double radiusHeroLarge = 34.0;

  /// Sheet over a hero cover (top corners only).
  static const double radiusSheet = 34.0;

  /// Spend panel, profile card.
  static const double radiusPanel = 28.0;

  /// Feature tile, memory tile, trip thumb, badge tile.
  static const double radiusTile = 26.0;

  /// Calendar card, day row.
  static const double radiusCard = 24.0;

  /// Standard card and list row.
  static const double radiusRow = 22.0;

  /// Input field.
  static const double radiusInput = 22.0;

  /// Social auth button, day rail item.
  static const double radiusMedium = 20.0;

  /// Small icon chip — map controls, file thumbs, settings icons.
  static const double radiusChip = 14.0;
  static const double radiusChipSm = 11.0;
  static const double radiusChipXs = 8.0;

  /// Chart bar.
  static const double radiusBar = 6.0;

  /// Calendar day cell, idle.
  static const double radiusDay = 12.0;

  /// Calendar range endpoint — the rounded end of the pill.
  static const double radiusDayEnd = 14.0;

  /// Calendar range middle.
  static const double radiusDayMid = 4.0;

  // Legacy scale, kept so unconverted call sites still resolve. Each maps to
  // the nearest value in the new system.
  static const double radiusXs = radiusChipXs;
  static const double radiusSm = radiusDay;
  static const double radiusMd = radiusChip;
  static const double radiusLg = radiusRow;
  static const double radiusXl = radiusHero;
  static const double radius2xl = radiusSheet;

  // ============================================================
  // CIRCLES
  // ============================================================
  // Diameters used by the circular icon buttons throughout the design.

  static const double circleSm = 36.0;
  static const double circleNotification = 38.0;
  static const double circleAction = 40.0;
  static const double circleSearch = 42.0;
  static const double circleBack = 44.0;
  static const double circleBadgeMark = 44.0;
  static const double circleIntroArrow = 56.0;
  static const double circleHeroArrow = 54.0;
  static const double circleAvatarLarge = 54.0;

  /// Minimum tap target. The 40px circles sit inside padded rows so the real
  /// target stays at least this wide.
  static const double minTouchTarget = 44.0;

  // ============================================================
  // COMPONENTS
  // ============================================================

  /// Vertical padding inside a primary pill button.
  static const double buttonPadding = 17.0;

  /// Height of a primary pill button, padding included.
  static const double buttonHeightLg = 52.0;
  static const double buttonHeightMd = 46.0;
  static const double buttonHeightSm = 40.0;

  /// Calendar day cell height.
  static const double dayCellHeight = 38.0;

  /// Day-rail item width.
  static const double railItemWidth = 50.0;

  /// Timeline gutter holding the time, and the rail column beside it.
  static const double timelineGutter = 46.0;
  static const double timelineRail = 14.0;

  /// Indent that aligns a footer affordance with the timeline cards.
  static const double timelineIndent = 74.0;

  /// Settings switch.
  static const Size switchSize = Size(46, 28);
  static const double switchKnob = 22.0;

  /// Circular checkbox — activity cards and packing rows.
  static const double checkboxLarge = 28.0;
  static const double checkboxSmall = 26.0;
  static const double checkboxBorder = 1.6;

  /// Trip thumb on the home rail.
  static const double tripThumb = 150.0;

  /// Hero heights.
  static const double homeHeroHeight = 320.0;
  static const double coverHeight = 420.0;
  static const double introPhotoHeight = 520.0;
  static const double mapHeight = 470.0;

  /// The sheet's overlap onto the cover above it.
  static const double sheetOverlap = -26.0;

  /// Map pins.
  static const double pinIdle = 15.0;
  static const double pinSelected = 22.0;
  static const double pinRing = 3.0;

  /// Progress bars.
  static const double progressHeight = 7.0;
  static const double categoryBarHeight = 12.0;
  static const double spendBarHeight = 10.0;

  /// Blur sigma behind a floating bar. The design specifies
  /// `backdrop-filter: blur(18px)`; CSS blur radius is roughly 2× the Gaussian
  /// sigma, so 18px maps to sigma 9.
  static const double glassBlur = 9.0;

  /// The lighter blur on the selected-pin card.
  static const double glassBlurLight = 7.0;

  // ============================================================
  // ICONS
  // ============================================================

  static const double iconXs = 13.0;
  static const double iconSm = 15.0;
  static const double iconMd = 17.0;
  static const double iconLg = 22.0;
  static const double iconXl = 32.0;

  // ============================================================
  // BORDERS
  // ============================================================

  static const double hairlineWidth = 1.0;
  static const double inputBorderWidth = 1.0;
  static const double inputFocusBorderWidth = 1.0;
  static const double ringWidth = 1.6;

  // ============================================================
  // ELEVATION
  // ============================================================
  // There are no drop shadows in this system. These stay at zero so any
  // Material widget that asks for an elevation gets a flat one.

  static const double cardElevation = 0.0;
  static const double appBarElevation = 0.0;

  /// Odyssey 2.0 has no drop shadows — depth comes from translucent layering
  /// and hairlines. These stay as empty lists so the call sites that still
  /// pass a `boxShadow` render flat instead of failing to compile; they are
  /// removed as each screen is converted.
  static const List<BoxShadow> softShadow = <BoxShadow>[];
  static const List<BoxShadow> mediumShadow = <BoxShadow>[];
  static const List<BoxShadow> strongShadow = <BoxShadow>[];

  // ============================================================
  // MOTION
  // ============================================================

  /// State changes — chip, tab, checkbox, switch. Colour and transform only.
  static const Duration durationState = Duration(milliseconds: 160);

  /// Switch knob travel.
  static const Duration durationKnob = Duration(milliseconds: 180);

  /// Panel swap — cross-fade plus an 8px upward slide on enter.
  static const Duration durationPanel = Duration(milliseconds: 180);

  /// Map pin selection — scale and colour.
  static const Duration durationPin = Duration(milliseconds: 200);

  /// Press feedback.
  static const Duration durationPress = Duration(milliseconds: 90);

  /// Skeleton pulse.
  static const Duration durationPulse = Duration(milliseconds: 1200);

  /// Height of the home screen's horizontal trip-thumbnail strip.
  static const double homeThumbStrip = 200;

  /// The skeleton standing in for a summary row's right-aligned value.
  static const double summaryValueSkeleton = 64;

  /// One pass of the highlight across a skeleton.
  static const Duration durationShimmer = Duration(milliseconds: 1500);

  /// One sweep of the indeterminate wait track.
  static const Duration durationWaitSweep = Duration(milliseconds: 1400);

  /// The skeleton bars standing in for a stat tile's numeral and its label.
  static const double statSkeletonValue = 52;
  static const double statSkeletonValueHeight = 22;
  static const double statSkeletonLabel = 34;
  static const double statSkeletonLabelHeight = 9;

  /// The brand mark on a full-screen wait.
  static const double markWait = 56;

  static const double waitTrackWidth = 140;
  static const double waitTrackHeight = 3;

  // Legacy duration names.
  static const Duration durationMicro = Duration(milliseconds: 100);
  static const Duration durationFast = durationState;
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationMedium = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 450);

  static const Curve curveState = Curves.easeOut;

  /// `cubic-bezier(0.2, 0.8, 0.2, 1)` — the switch knob.
  static const Curve curveKnob = Cubic(0.2, 0.8, 0.2, 1);

  /// Scale applied to a tappable surface while pressed.
  static const double pressScale = 0.98;

  // ============================================================
  // PARALLAX
  // ============================================================

  /// Optional hero parallax on the trip detail cover. The design caps the
  /// scroll factor at 0.3.
  static const double parallaxSpeed = 0.3;
  static const double parallaxMaxOffset = 120.0;

  // ============================================================
  // BREAKPOINTS
  // ============================================================

  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;

  // Legacy names still referenced by unconverted widgets.
  static const double activityCardHeight = 100.0;
  static const double tripCardHeight = 260.0;
  static const double cardBlur = glassBlur;
  static const double avatarSm = 32.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double inputHeight = 56.0;
}
