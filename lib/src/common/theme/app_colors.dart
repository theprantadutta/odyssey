import 'package:flutter/material.dart';

/// Odyssey 2.0 palette.
///
/// Near-black (or paper-white) canvas, photography full-bleed to the card
/// edge, and exactly one high-voltage accent — acid lime — carrying every
/// piece of emphasis in the product. There are no drop shadows: depth comes
/// from translucent layering and 1px hairlines.
///
/// These are the raw values. Screens should almost never reach for them
/// directly — read `OdysseyTokens` off the theme instead, which resolves the
/// light/dark pair and the accent-inversion rule for you.
class AppColors {
  AppColors._();

  // ============================================================
  // BRAND
  // ============================================================

  /// Acid lime. The single accent, identical in both themes.
  static const Color accent = Color(0xFFD6FF3D);

  /// Near-black. Canvas in dark, ink and primary action colour in light.
  static const Color obsidian = Color(0xFF0A0B0D);

  /// Paper white. Canvas in light, ink in dark.
  static const Color paper = Color(0xFFF2F2EF);

  /// Lime is unreadable as body text on a light canvas, so light-theme
  /// "unlocked / earned" labels use this instead.
  static const Color limeInk = Color(0xFF5C7A00);

  // ============================================================
  // DARK THEME
  // ============================================================

  static const Color darkCanvas = obsidian;
  static const Color darkSheet = Color(0xFF111316);
  static const Color darkCard = Color(0x0BFFFFFF); // white @ .045
  static const Color darkCardAlt = Color(0x12FFFFFF); // white @ .07
  static const Color darkHairline = Color(0x14FFFFFF); // .08
  static const Color darkHairlineStrong = Color(0x1AFFFFFF); // .10
  static const Color darkSeparator = Color(0x12FFFFFF); // .07
  static const Color darkTrack = Color(0x0DFFFFFF); // .05
  static const Color darkInk = paper;
  static const Color darkInk2 = Color(0x99F2F2EF); // .60
  static const Color darkInk3 = Color(0x6BF2F2EF); // .42
  static const Color darkGlass = Color(0xD116181B); // rgb(22,24,27) @ .82
  static const Color darkDashed = Color(0x2EFFFFFF); // .18
  static const Color darkMapBase = Color(0xFF14171C);

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static const Color lightCanvas = paper;
  static const Color lightSheet = paper;
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardAlt = paper;
  static const Color lightHairline = Color(0x120A0B0D); // .07
  static const Color lightHairlineStrong = Color(0x140A0B0D); // .08
  static const Color lightSeparator = Color(0x0F0A0B0D); // .06
  static const Color lightTrack = Color(0x0D0A0B0D); // .05
  static const Color lightInk = obsidian;
  static const Color lightInk2 = Color(0x8C0A0B0D); // .55
  static const Color lightInk3 = Color(0x6B0A0B0D); // .42
  static const Color lightGlass = Color(0xE6FFFFFF); // white @ .90
  static const Color lightDashed = Color(0x290A0B0D); // .16
  static const Color lightMapBase = Color(0xFFE4E4DE);

  // ============================================================
  // ON PHOTOGRAPHY
  // ============================================================
  // Text over an image is always the light-on-dark set regardless of theme —
  // the scrim guarantees contrast. Keep the scrim if you change the imagery.

  static const Color onPhoto = paper;
  static const Color onPhoto2 = Color(0xA8F2F2EF); // .66
  static const Color onPhoto3 = Color(0xD9F2F2EF); // .85
  static const Color photoTagBg = Color(0x660A0B0D); // .40
  static const Color photoTagBorder = Color(0x29FFFFFF); // .16
  static const Color photoChipBg = Color(0x730A0B0D); // .45

  /// Scrim laid under text that sits on a photo: dark at the top for status
  /// bar legibility, clear through the middle, dark again at the foot.
  static const LinearGradient photoScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x730A0B0D), Color(0x000A0B0D), Color(0xD90A0B0D)],
    stops: [0.18, 0.40, 1.0],
  );

  // ============================================================
  // ON LIME
  // ============================================================
  // Text on lime is always obsidian — never white.

  static const Color onAccent = obsidian;
  static const Color onAccent2 = Color(0xA60A0B0D); // .65
  static const Color onAccentLabel = Color(0x8C0A0B0D); // .55 — mono eyebrows
  static const Color onAccentTrack = Color(0x240A0B0D); // .14 — progress track
  static const Color onAccentDecor = Color(0x0F0A0B0D); // .06 — corner circle

  // ============================================================
  // TINTS
  // ============================================================
  // "Earned / checked / done" surfaces. Dark tints faintly and leans on a
  // lime border; light tints hard and leans on an ink border.

  static const Color darkAccentTint = Color(0x17D6FF3D); // .09
  static const Color darkAccentTintBorder = Color(0x59D6FF3D); // .35
  static const Color lightAccentTint = Color(0x4DD6FF3D); // .30
  static const Color lightAccentTintBorder = Color(0x1F0A0B0D); // .12

  /// Calendar range middle.
  static const Color darkRangeFill = Color(0x24D6FF3D); // .14
  static const Color lightRangeFill = Color(0x120A0B0D); // .07

  // ============================================================
  // DATA RAMP
  // ============================================================
  // Four tones for charts, category bars and expense chips. Ordered most to
  // least emphatic; wrap around if a dataset runs longer.

  static const List<Color> darkRamp = [
    accent,
    Color(0x99D6FF3D), // .60
    Color(0x52FFFFFF), // .32
    Color(0x24FFFFFF), // .14
  ];

  static const List<Color> lightRamp = [
    obsidian,
    accent,
    Color(0x610A0B0D), // .38
    Color(0x240A0B0D), // .14
  ];

  // ============================================================
  // PHOTO PLACEHOLDER GRADIENTS
  // ============================================================
  // Stand-ins for real imagery. An entity with no cover renders one of these
  // rather than a flat grey box, picked by hashing its id.

  static const LinearGradient kyotoGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF14202B), Color(0xFF2E4A3A), Color(0xFF8FA83F), accent],
    stops: [0.0, 0.39, 0.77, 1.0],
  );

  static const LinearGradient autumnGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1B1410),
      Color(0xFF4A2B20),
      Color(0xFFA35A32),
      Color(0xFFE6A552),
    ],
    stops: [0.0, 0.42, 0.75, 1.0],
  );

  static const LinearGradient greenStayGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C2A24), Color(0xFF3E5A44), Color(0xFF8FA86A)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient blueStayGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1F2B), Color(0xFF374863), Color(0xFF7E93B8)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient marrakechGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF241A14), Color(0xFF4A2B20), Color(0xFFC77A45)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient boardingPassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B2410), Color(0xFF4A5A20), accent],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient darkAvatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A3F2B), accent],
  );

  /// The rotation used wherever a set of placeholder covers appears at once
  /// (recent trips, stays, memory tiles, leaderboard avatars).
  static const List<LinearGradient> photoGradients = [
    kyotoGradient,
    autumnGradient,
    blueStayGradient,
    marrakechGradient,
    greenStayGradient,
  ];

  /// Picks a stable placeholder gradient for an entity with no cover image,
  /// so the same trip always renders the same colours.
  static LinearGradient gradientFor(String seed) {
    if (seed.isEmpty) return kyotoGradient;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return photoGradients[hash % photoGradients.length];
  }

  // ============================================================
  // ELEVATION
  // ============================================================

  /// The only shadow in the entire system — the selected map pin.
  static const List<BoxShadow> activePinGlow = [
    BoxShadow(
      color: Color(0xCCD6FF3D), // .80
      blurRadius: 16,
      spreadRadius: -4,
      offset: Offset(0, 6),
    ),
  ];

  // ============================================================
  // SEMANTIC
  // ============================================================
  // There is no red in this palette. Failure is signalled with copy, not
  // colour. These exist only because Material's ColorScheme demands values;
  // they are deliberately the ink pair so a stray framework error state
  // stays on-system rather than punching a hole in it.

  static const Color error = obsidian;
  static const Color onError = paper;

  // ============================================================
  // LEGACY SHIM — delete once every screen is converted
  // ============================================================
  //
  // The retired "Sunny Yellow / Nunito / Inter" system spread its palette
  // across ~90 files. Rather than leave the app uncompilable for the length of
  // the conversion, every old name still resolves — mapped onto the nearest
  // Odyssey 2.0 token so an unconverted screen renders monochrome-plus-lime
  // instead of reintroducing a second accent.
  //
  // The four secondary accents (teal, coral, lavender, sky) deliberately
  // collapse onto ink levels: this system has exactly one accent, and a
  // screen that still asks for "the teal one" should get a neutral, not a
  // colour that fights the lime.
  //
  // Nothing new should reference anything below this line.

  @Deprecated('Use OdysseyTokens.action or AppColors.accent')
  static const Color sunnyYellow = accent;
  @Deprecated('Use OdysseyTokens.action or AppColors.accent')
  static const Color sunsetGold = accent;
  @Deprecated('Use OdysseyTokens.action or AppColors.accent')
  static const Color goldenGlow = accent;
  @Deprecated('Use OdysseyTokens.action or AppColors.accent')
  static const Color softGold = accent;
  @Deprecated('Use OdysseyTokens.accentTint')
  static const Color lemonLight = lightAccentTint;
  @Deprecated('Use OdysseyTokens.accentTint')
  static const Color paleGold = lightAccentTint;
  @Deprecated('Use OdysseyTokens.accentTint')
  static const Color softCream = lightAccentTint;

  @Deprecated('This system has one accent; use OdysseyTokens.ink2')
  static const Color oceanTeal = lightInk2;
  @Deprecated('This system has one accent; use OdysseyTokens.ink2')
  static const Color mintGreen = lightInk2;
  @Deprecated('This system has one accent; use OdysseyTokens.ink2')
  static const Color coralBurst = lightInk2;
  @Deprecated('This system has one accent; use OdysseyTokens.ink2')
  static const Color coralPink = lightInk2;
  @Deprecated('This system has one accent; use OdysseyTokens.ink2')
  static const Color lavenderDream = lightInk2;
  @Deprecated('This system has one accent; use OdysseyTokens.ink2')
  static const Color skyBlue = lightInk2;

  @Deprecated('Use OdysseyTokens.ink')
  static const Color charcoal = obsidian;
  @Deprecated('Use OdysseyTokens.ink')
  static const Color textPrimary = obsidian;
  @Deprecated('Use OdysseyTokens.ink2')
  static const Color slate = lightInk2;
  @Deprecated('Use OdysseyTokens.ink2')
  static const Color textSecondary = lightInk2;
  @Deprecated('Use OdysseyTokens.ink3')
  static const Color mutedGray = lightInk3;
  @Deprecated('Use OdysseyTokens.ink3')
  static const Color textTertiary = lightInk3;
  @Deprecated('Use AppColors.paper')
  static const Color pureWhite = Color(0xFFFFFFFF);
  @Deprecated('Use AppColors.paper')
  static const Color textOnDark = paper;
  @Deprecated('Use OdysseyTokens.card')
  static const Color snowWhite = Color(0xFFFFFFFF);
  @Deprecated('Use OdysseyTokens.canvas')
  static const Color cloudGray = paper;
  @Deprecated('Use OdysseyTokens.canvas')
  static const Color frostedWhite = paper;
  @Deprecated('Use OdysseyTokens.cardAlt')
  static const Color warmGray = paper;

  @Deprecated('Use OdysseyTokens.canvas')
  static const Color midnightBlue = obsidian;
  @Deprecated('Use OdysseyTokens.sheet')
  static const Color deepNavy = darkSheet;
  @Deprecated('Use OdysseyTokens.cardAlt')
  static const Color navyAccent = Color(0xFF1A1C20);

  @Deprecated('No colour semantics in this palette; signal with copy')
  static const Color success = obsidian;
  @Deprecated('No colour semantics in this palette; signal with copy')
  static const Color warning = obsidian;
  @Deprecated('No colour semantics in this palette; signal with copy')
  static const Color info = obsidian;

  @Deprecated('Use OdysseyTokens.glass')
  static const Color glassSurface = lightGlass;
  @Deprecated('Use OdysseyTokens.glass')
  static const Color darkGlassSurface = darkGlass;

  @Deprecated('No drop shadows in this system')
  static Color get softShadow => const Color(0x00000000);
  @Deprecated('No drop shadows in this system')
  static Color get mediumShadow => const Color(0x00000000);
  @Deprecated('No drop shadows in this system')
  static Color get yellowGlow => const Color(0x00000000);

  @Deprecated('Use OdysseyTokens.accent')
  static const Color statusPlanned = accent;
  @Deprecated('Use OdysseyTokens.accentTint')
  static const Color statusPlannedBg = lightAccentTint;
  @Deprecated('Use OdysseyTokens.accent')
  static const Color statusOngoing = accent;
  @Deprecated('Use OdysseyTokens.accentTint')
  static const Color statusOngoingBg = lightAccentTint;
  @Deprecated('Use OdysseyTokens.ink')
  static const Color statusCompleted = obsidian;
  @Deprecated('Use OdysseyTokens.cardAlt')
  static const Color statusCompletedBg = lightCardAlt;

  @Deprecated('Use a photo gradient or a flat token surface')
  static const LinearGradient sunshineGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accent],
  );
  @Deprecated('Use a photo gradient or a flat token surface')
  static const LinearGradient primaryGradient = sunshineGradient;
  @Deprecated('Use a photo gradient or a flat token surface')
  static const LinearGradient goldGradient = sunshineGradient;
  @Deprecated('Use a photo gradient or a flat token surface')
  static const LinearGradient playfulGradient = kyotoGradient;
  @Deprecated('Use a flat token surface')
  static const LinearGradient softBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [paper, paper],
  );
  @Deprecated('Use a flat token surface')
  static const LinearGradient cardGradient = softBackgroundGradient;
  @Deprecated('Use OdysseyTokens.glass with a BackdropFilter')
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x14FFFFFF), Color(0x0BFFFFFF)],
  );
}
