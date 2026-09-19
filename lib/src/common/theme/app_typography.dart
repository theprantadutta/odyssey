import 'package:flutter/material.dart';

/// Odyssey 2.0 type system.
///
/// Two families and a mono:
///
/// * **Space Grotesk** — display and *all* numerals. Always weight 700, always
///   tight. The tracking gets tighter as the size grows, which is why every
///   display role below carries its own [TextStyle.letterSpacing] rather than
///   inheriting one.
/// * **Manrope** — all UI text and body copy. Weights 500 / 600 / 700 / 800.
/// * **JetBrains Mono** — eyebrow labels only. Uppercase, widely tracked.
///
/// All three are bundled in `assets/fonts` and declared in `pubspec.yaml`, so
/// there is no runtime font fetch — this app has to look right offline on a
/// cold first launch.
///
/// Tracking in the design is specified in `em`; Flutter wants logical pixels.
/// Every value here is already converted (`em × fontSize`), so the numbers
/// look arbitrary but are exact.
///
/// **The floor for body text is 11px.** Eyebrow labels sit at 9–9.5px and are
/// uppercase mono only.
class AppTypography {
  AppTypography._();

  static const String display = 'SpaceGrotesk';
  static const String ui = 'Manrope';
  static const String mono = 'JetBrainsMono';

  // ============================================================
  // DISPLAY — Space Grotesk 700
  // ============================================================

  /// Screen hero title. 40px, −0.04em. Usually two lines.
  ///
  /// "Where to / next, Pranta?" · "Your / travel year"
  static const TextStyle heroTitle = TextStyle(
    fontFamily: display,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.6,
    height: 1.0,
  );

  /// The smaller hero used where a screen has a header row above it. 34px.
  ///
  /// "New trip" · "Travel wallet" · "You"
  static const TextStyle screenTitle = TextStyle(
    fontFamily: display,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.36,
    height: 1.0,
  );

  /// Day-plan title. 36px, −0.04em.
  static const TextStyle dayTitle = TextStyle(
    fontFamily: display,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.44,
    height: 1.0,
  );

  /// Place name on a full-bleed cover. 52px, −0.045em, very tight leading.
  static const TextStyle placeName = TextStyle(
    fontFamily: display,
    fontSize: 52,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.34,
    height: 0.94,
  );

  /// Destination on the home hero card. 32px, −0.035em.
  static const TextStyle heroPlace = TextStyle(
    fontFamily: display,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.12,
    height: 1.02,
  );

  /// The giant number on a lime hero tile. 68px, −0.05em, leading 0.85.
  ///
  /// "days on the road"
  static const TextStyle statGiant = TextStyle(
    fontFamily: display,
    fontSize: 68,
    fontWeight: FontWeight.w700,
    letterSpacing: -3.4,
    height: 0.85,
  );

  /// Achievements points / packing percentage. 58–60px.
  static const TextStyle statHuge = TextStyle(
    fontFamily: display,
    fontSize: 58,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.9,
    height: 0.85,
  );

  /// Budget total. 52px, −0.05em.
  static const TextStyle statTotal = TextStyle(
    fontFamily: display,
    fontSize: 52,
    fontWeight: FontWeight.w700,
    letterSpacing: -2.6,
    height: 0.9,
  );

  /// Spend panel amount, statistics bento halves. 40px, −0.045em.
  static const TextStyle statLarge = TextStyle(
    fontFamily: display,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.8,
    height: 1.0,
  );

  /// Statistics half-tile value. 36px, −0.045em.
  static const TextStyle statMedium = TextStyle(
    fontFamily: display,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.62,
    height: 1.0,
  );

  /// Section value / distance flown. 34px, −0.04em.
  static const TextStyle statSection = TextStyle(
    fontFamily: display,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.36,
    height: 1.0,
  );

  /// Boarding-pass route. 30px, −0.04em.
  static const TextStyle route = TextStyle(
    fontFamily: display,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.0,
  );

  /// "Memories" wall heading, budget tile values. 26px, −0.04em.
  static const TextStyle statCard = TextStyle(
    fontFamily: display,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.04,
    height: 1.0,
  );

  /// Trip-detail stat row. 24px, −0.04em.
  static const TextStyle statSmall = TextStyle(
    fontFamily: display,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.96,
    height: 1.0,
  );

  /// Day-rail date. 18px, −0.03em.
  static const TextStyle railDate = TextStyle(
    fontFamily: display,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.54,
    height: 1.0,
  );

  /// Numerals at list scale — expense amounts, leaderboard points, timeline
  /// times. 13–14px, −0.02em.
  static const TextStyle numeral = TextStyle(
    fontFamily: display,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.26,
    height: 1.0,
  );

  /// Glyph arrows and marks: `←` `→` `›` `✕` `+` `−` `✓`.
  ///
  /// Size and colour are set per use; this just pins the family and weight.
  static const TextStyle glyph = TextStyle(
    fontFamily: display,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  // ============================================================
  // UI — Manrope
  // ============================================================

  /// Section heading. 17px / 700, −0.01em.
  static const TextStyle sectionHeading = TextStyle(
    fontFamily: ui,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.17,
    height: 1.2,
  );

  /// Card title at the larger end — stay names, profile name. 17px / 700.
  static const TextStyle cardTitleLarge = TextStyle(
    fontFamily: ui,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Activity card title. 16px / 700.
  static const TextStyle cardTitleXl = TextStyle(
    fontFamily: ui,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Field value inside an input card. 15px / 600.
  static const TextStyle fieldValue = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// From/To summary value. 15px / 700.
  static const TextStyle fieldValueStrong = TextStyle(
    fontFamily: ui,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Trip card title on the home rail. 14.5px / 700.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: ui,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// List row title — packing items, expenses, documents. 14px / 700.
  static const TextStyle rowTitle = TextStyle(
    fontFamily: ui,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Settings row label. 13.5px / 700.
  static const TextStyle rowLabel = TextStyle(
    fontFamily: ui,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Body copy. 14.5px / 500, generous leading.
  static const TextStyle body = TextStyle(
    fontFamily: ui,
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    height: 1.6,
  );

  /// Sub-line under a screen title. 14px / 500.
  static const TextStyle subtitle = TextStyle(
    fontFamily: ui,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// Search placeholder. 14px / 500.
  static const TextStyle placeholder = TextStyle(
    fontFamily: ui,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Primary button label. 14px / 700.
  static const TextStyle button = TextStyle(
    fontFamily: ui,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Secondary / outline button label. 13px / 700.
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: ui,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Meta line under a hero, cover date range. 13px / 500.
  static const TextStyle meta = TextStyle(
    fontFamily: ui,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// Hero card meta on a photo. 12.5px / 500.
  static const TextStyle metaLarge = TextStyle(
    fontFamily: ui,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// Chip and segmented-tab label. 12.5px / 600.
  static const TextStyle chip = TextStyle(
    fontFamily: ui,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Selected segmented-tab label — same size, heavier. 12.5px / 700.
  static const TextStyle tab = TextStyle(
    fontFamily: ui,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Header caption, "See all", right-aligned settings value. 12px / 700.
  static const TextStyle caption = TextStyle(
    fontFamily: ui,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Location pill, footer link. 12px / 600.
  static const TextStyle pill = TextStyle(
    fontFamily: ui,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Nav item label. 11.5px / 700.
  static const TextStyle navLabel = TextStyle(
    fontFamily: ui,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Row meta — "24 memories", "format · size · note". 11.5px / 500.
  ///
  /// This is the floor for readable meta text.
  static const TextStyle rowMeta = TextStyle(
    fontFamily: ui,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  /// Legend label, "Show" affordance. 11.5px / 600.
  static const TextStyle legend = TextStyle(
    fontFamily: ui,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Badge description. 11px / 500, 1.45 leading.
  static const TextStyle badgeDesc = TextStyle(
    fontFamily: ui,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );

  /// Countdown pill on a photo. 11px / 700.
  static const TextStyle countdown = TextStyle(
    fontFamily: ui,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Lime badge — `DAY 3 / 6`, `CONFIRMED`, `PRO`. 10px / 700, 0.06em.
  static const TextStyle badge = TextStyle(
    fontFamily: ui,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.2,
  );

  /// Trip-detail stat label. 10.5px / 600.
  static const TextStyle statLabel = TextStyle(
    fontFamily: ui,
    fontSize: 10.5,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Day-rail weekday, chart bar label. 9.5–10px / 600–700, lightly tracked.
  static const TextStyle microLabel = TextStyle(
    fontFamily: ui,
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.57,
    height: 1.2,
  );

  /// Avatar initial. 14px / 800.
  static const TextStyle avatarInitial = TextStyle(
    fontFamily: ui,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.0,
  );

  // ============================================================
  // MONO — eyebrow labels only
  // ============================================================

  /// Eyebrow label. 9.5px / 700, 0.16em, ALL CAPS.
  ///
  /// `NEXT TRIP` · `ODYSSEY POINTS` · `DAYS ON THE ROAD` · `REMAINING`
  ///
  /// Always pass already-uppercased copy — `EyebrowLabel` handles that for you.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: mono,
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.52,
    height: 1.2,
  );

  /// Eyebrow at the tighter tracking used inside dense cards. 9px / 700, 0.14em.
  static const TextStyle eyebrowTight = TextStyle(
    fontFamily: mono,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.26,
    height: 1.2,
  );

  /// Mono row tag — `DOCS` / `TECH` / `WEAR`. 9px / 700, 0.12em.
  static const TextStyle monoTag = TextStyle(
    fontFamily: mono,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.08,
    height: 1.2,
  );

  /// The `photo · …` tag on a placeholder image. 9px / 400, lowercase.
  static const TextStyle photoTag = TextStyle(
    fontFamily: mono,
    fontSize: 9,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.72,
    height: 1.2,
  );

  /// File-extension label on a document thumb. 8.5px / 400, 0.06em.
  static const TextStyle fileExt = TextStyle(
    fontFamily: mono,
    fontSize: 8.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.51,
    height: 1.2,
  );

  /// Divider word (`OR`) and the build stamp. 11px / 700, 0.1em.
  static const TextStyle monoDivider = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    height: 1.2,
  );

  // ============================================================
  // LEGACY SHIM — delete once every screen is converted
  // ============================================================
  //
  // The retired system named its styles after Material's size ladder. Those
  // names survive here, mapped onto the closest Odyssey 2.0 role, so an
  // unconverted screen keeps compiling and already renders in the new
  // typefaces rather than in Nunito and Inter.
  //
  // Nothing new should reference anything below this line — the roles above
  // are named for what they are, which is the point of the system.

  @Deprecated('Use AppTypography.statGiant')
  static const TextStyle displayLarge = statGiant;
  @Deprecated('Use AppTypography.heroTitle')
  static const TextStyle displayMedium = heroTitle;
  @Deprecated('Use AppTypography.screenTitle')
  static const TextStyle displaySmall = screenTitle;
  @Deprecated('Use AppTypography.screenTitle')
  static const TextStyle brandLarge = screenTitle;

  @Deprecated('Use AppTypography.statSection')
  static const TextStyle headlineLarge = statSection;
  @Deprecated('Use AppTypography.statCard')
  static const TextStyle headlineMedium = statCard;
  @Deprecated('Use AppTypography.sectionHeading')
  static const TextStyle headlineSmall = sectionHeading;

  @Deprecated('Use AppTypography.sectionHeading')
  static const TextStyle titleLarge = sectionHeading;
  @Deprecated('Use AppTypography.cardTitleXl')
  static const TextStyle titleMedium = cardTitleXl;
  @Deprecated('Use AppTypography.rowTitle')
  static const TextStyle titleSmall = rowTitle;

  @Deprecated('Use AppTypography.body')
  static const TextStyle bodyLarge = body;
  @Deprecated('Use AppTypography.subtitle')
  static const TextStyle bodyMedium = subtitle;
  @Deprecated('Use AppTypography.rowMeta')
  static const TextStyle bodySmall = rowMeta;

  @Deprecated('Use AppTypography.button')
  static const TextStyle labelLarge = button;
  @Deprecated('Use AppTypography.chip')
  static const TextStyle labelMedium = chip;
  @Deprecated('Use AppTypography.legend')
  static const TextStyle labelSmall = legend;

  @Deprecated('Use AppTypography.rowMeta')
  static const TextStyle caption2 = rowMeta;
  @Deprecated('Use AppTypography.eyebrow')
  static const TextStyle overline = eyebrow;
}
