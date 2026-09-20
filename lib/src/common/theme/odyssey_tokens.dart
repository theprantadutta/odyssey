import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The Odyssey 2.0 design tokens, resolved for the active theme.
///
/// Material's [ColorScheme] has nowhere to put most of what this design system
/// needs — three ink levels, two hairline weights, a glass fill, a dashed
/// border colour, a four-tone data ramp — so the whole token table rides on
/// the theme as an extension instead.
///
/// Read it with [OdysseyTokenLookup.odyssey]:
///
/// ```dart
/// final t = context.odyssey;
/// Container(color: t.card, child: Text('Kyoto', style: t.…));
/// ```
///
/// ## The accent inversion rule
///
/// Lime is the accent in both themes, but what it pairs with flips. Rather
/// than branching on [isDark] at every call site, use the resolved trio:
///
/// * [action] — the primary action fill. Lime in dark, ink in light.
/// * [onAction] — text and icons sitting on [action].
/// * [actionGlyph] — the *highlight* inside an [action] surface: the arrow in
///   a filled circle, an avatar initial, a nav mark. Ink in dark, lime in
///   light. This is the piece that makes the light theme read as designed.
///
/// [invert] / [onInvert] are the separate "inverted chip" pair used by home
/// filter chips and segmented controls, which flip to paper-on-obsidian in
/// dark rather than to lime.
///
/// Hero stat tiles are the one place the themes agree: they stay lime in both.
/// Use [heroTile] / [onHeroTile] for those, never [action].
@immutable
class OdysseyTokens extends ThemeExtension<OdysseyTokens> {
  const OdysseyTokens({
    required this.isDark,
    required this.canvas,
    required this.sheet,
    required this.card,
    required this.cardAlt,
    required this.skeleton,
    required this.skeletonSheen,
    required this.hairline,
    required this.hairlineStrong,
    required this.separator,
    required this.track,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.glass,
    required this.dashed,
    required this.action,
    required this.onAction,
    required this.actionGlyph,
    required this.invert,
    required this.onInvert,
    required this.limeText,
    required this.accentTint,
    required this.accentTintBorder,
    required this.rangeFill,
    required this.ramp,
    required this.mapBase,
    required this.pressTint,
  });

  /// True when the dark theme is active. Prefer the resolved tokens over
  /// branching on this; reach for it only where the design genuinely differs
  /// in kind rather than in colour (e.g. the avatar is a gradient in dark and
  /// a flat fill in light).
  final bool isDark;

  // --- surfaces ---

  /// Screen background.
  final Color canvas;

  /// Raised panel that overlaps a hero photo (trip detail).
  final Color sheet;

  /// Standard card surface.
  final Color card;

  /// Slightly heavier card — map tiles, icon chips, file thumbs.
  final Color cardAlt;

  /// The block a [Skeleton] is drawn in.
  ///
  /// Deliberately not [cardAlt]. In the light theme cardAlt *is* the canvas
  /// colour, so a skeleton drawn in it is invisible against the page - loading
  /// looked exactly like empty. This tone is chosen to read against the canvas
  /// in both themes.
  final Color skeleton;

  /// The highlight that sweeps across a [Skeleton]. Lighter than [skeleton] in
  /// both themes.
  final Color skeletonSheen;

  /// Fill behind a floating bar. Pair with a `BackdropFilter`; see
  /// `GlassBar`, which does both.
  final Color glass;

  /// Base colour of the map canvas beneath the tile layer.
  final Color mapBase;

  // --- lines ---

  /// 1px border on cards and list rows.
  final Color hairline;

  /// 1px border on nav bars and pills, a touch stronger.
  final Color hairlineStrong;

  /// Divider between rows inside a single grouped card.
  final Color separator;

  /// Segmented-control and progress-bar track.
  final Color track;

  /// Dashed border on empty states and "add" affordances.
  final Color dashed;

  // --- text ---

  /// Primary text.
  final Color ink;

  /// Secondary text.
  final Color ink2;

  /// Tertiary text and eyebrow labels. Never use for anything a user must
  /// read in order to act.
  final Color ink3;

  // --- action ---

  /// Primary action fill: lime in dark, ink in light.
  final Color action;

  /// Text and icons on [action].
  final Color onAction;

  /// Highlight glyph *inside* an [action] surface: ink in dark, lime in light.
  final Color actionGlyph;

  /// Inverted chip/tab fill: paper in dark, ink in light.
  final Color invert;

  /// Text on [invert].
  final Color onInvert;

  /// Lime semantics at body size — real lime in dark, a darkened lime in
  /// light where the pure accent would fail contrast.
  final Color limeText;

  // --- states ---

  /// "Done / packed / earned" surface fill.
  final Color accentTint;

  /// Border for an [accentTint] surface.
  final Color accentTintBorder;

  /// Calendar range middle fill.
  final Color rangeFill;

  /// Background tint applied to a row while pressed.
  final Color pressTint;

  /// Four-tone ramp for charts, category bars and expense chips.
  final List<Color> ramp;

  // --- constants (identical in both themes) ---

  /// Hero stat tiles stay lime in both themes. This is intentional: it keeps
  /// the brand moment constant.
  Color get heroTile => AppColors.accent;

  /// Text on [heroTile].
  Color get onHeroTile => AppColors.onAccent;

  /// The accent itself, for the handful of places that want lime regardless
  /// of the inversion rule (the countdown dot on a photo, a lime badge).
  Color get accent => AppColors.accent;

  /// A ramp tone by index, wrapping for datasets longer than four.
  Color rampAt(int index) => ramp[index % ramp.length];

  static const OdysseyTokens dark = OdysseyTokens(
    isDark: true,
    canvas: AppColors.darkCanvas,
    sheet: AppColors.darkSheet,
    card: AppColors.darkCard,
    cardAlt: AppColors.darkCardAlt,
    skeleton: AppColors.darkSkeleton,
    skeletonSheen: AppColors.darkSkeletonSheen,
    hairline: AppColors.darkHairline,
    hairlineStrong: AppColors.darkHairlineStrong,
    separator: AppColors.darkSeparator,
    track: AppColors.darkTrack,
    ink: AppColors.darkInk,
    ink2: AppColors.darkInk2,
    ink3: AppColors.darkInk3,
    glass: AppColors.darkGlass,
    dashed: AppColors.darkDashed,
    action: AppColors.accent,
    onAction: AppColors.obsidian,
    actionGlyph: AppColors.obsidian,
    invert: AppColors.paper,
    onInvert: AppColors.obsidian,
    limeText: AppColors.accent,
    accentTint: AppColors.darkAccentTint,
    accentTintBorder: AppColors.darkAccentTintBorder,
    rangeFill: AppColors.darkRangeFill,
    ramp: AppColors.darkRamp,
    mapBase: AppColors.darkMapBase,
    pressTint: Color(0x08FFFFFF),
  );

  static const OdysseyTokens light = OdysseyTokens(
    isDark: false,
    canvas: AppColors.lightCanvas,
    sheet: AppColors.lightSheet,
    card: AppColors.lightCard,
    cardAlt: AppColors.lightCardAlt,
    skeleton: AppColors.lightSkeleton,
    skeletonSheen: AppColors.lightSkeletonSheen,
    hairline: AppColors.lightHairline,
    hairlineStrong: AppColors.lightHairlineStrong,
    separator: AppColors.lightSeparator,
    track: AppColors.lightTrack,
    ink: AppColors.lightInk,
    ink2: AppColors.lightInk2,
    ink3: AppColors.lightInk3,
    glass: AppColors.lightGlass,
    dashed: AppColors.lightDashed,
    action: AppColors.obsidian,
    onAction: AppColors.paper,
    actionGlyph: AppColors.accent,
    invert: AppColors.obsidian,
    onInvert: AppColors.paper,
    limeText: AppColors.limeInk,
    accentTint: AppColors.lightAccentTint,
    accentTintBorder: AppColors.lightAccentTintBorder,
    rangeFill: AppColors.lightRangeFill,
    ramp: AppColors.lightRamp,
    mapBase: AppColors.lightMapBase,
    pressTint: Color(0x080A0B0D),
  );

  /// A 1px border in the standard hairline weight.
  Border get hairlineBorder => Border.all(color: hairline, width: 1);

  /// A 1px border in the heavier weight used by nav bars and pills.
  Border get strongBorder => Border.all(color: hairlineStrong, width: 1);

  @override
  OdysseyTokens copyWith({
    bool? isDark,
    Color? canvas,
    Color? sheet,
    Color? card,
    Color? cardAlt,
    Color? skeleton,
    Color? skeletonSheen,
    Color? hairline,
    Color? hairlineStrong,
    Color? separator,
    Color? track,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? glass,
    Color? dashed,
    Color? action,
    Color? onAction,
    Color? actionGlyph,
    Color? invert,
    Color? onInvert,
    Color? limeText,
    Color? accentTint,
    Color? accentTintBorder,
    Color? rangeFill,
    List<Color>? ramp,
    Color? mapBase,
    Color? pressTint,
  }) {
    return OdysseyTokens(
      isDark: isDark ?? this.isDark,
      canvas: canvas ?? this.canvas,
      sheet: sheet ?? this.sheet,
      card: card ?? this.card,
      cardAlt: cardAlt ?? this.cardAlt,
      skeleton: skeleton ?? this.skeleton,
      skeletonSheen: skeletonSheen ?? this.skeletonSheen,
      hairline: hairline ?? this.hairline,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      separator: separator ?? this.separator,
      track: track ?? this.track,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      glass: glass ?? this.glass,
      dashed: dashed ?? this.dashed,
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      actionGlyph: actionGlyph ?? this.actionGlyph,
      invert: invert ?? this.invert,
      onInvert: onInvert ?? this.onInvert,
      limeText: limeText ?? this.limeText,
      accentTint: accentTint ?? this.accentTint,
      accentTintBorder: accentTintBorder ?? this.accentTintBorder,
      rangeFill: rangeFill ?? this.rangeFill,
      ramp: ramp ?? this.ramp,
      mapBase: mapBase ?? this.mapBase,
      pressTint: pressTint ?? this.pressTint,
    );
  }

  @override
  OdysseyTokens lerp(covariant OdysseyTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return OdysseyTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      canvas: c(canvas, other.canvas),
      sheet: c(sheet, other.sheet),
      card: c(card, other.card),
      cardAlt: c(cardAlt, other.cardAlt),
      skeleton: c(skeleton, other.skeleton),
      skeletonSheen: c(skeletonSheen, other.skeletonSheen),
      hairline: c(hairline, other.hairline),
      hairlineStrong: c(hairlineStrong, other.hairlineStrong),
      separator: c(separator, other.separator),
      track: c(track, other.track),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      ink3: c(ink3, other.ink3),
      glass: c(glass, other.glass),
      dashed: c(dashed, other.dashed),
      action: c(action, other.action),
      onAction: c(onAction, other.onAction),
      actionGlyph: c(actionGlyph, other.actionGlyph),
      invert: c(invert, other.invert),
      onInvert: c(onInvert, other.onInvert),
      limeText: c(limeText, other.limeText),
      accentTint: c(accentTint, other.accentTint),
      accentTintBorder: c(accentTintBorder, other.accentTintBorder),
      rangeFill: c(rangeFill, other.rangeFill),
      ramp: [
        for (var i = 0; i < ramp.length; i++) c(ramp[i], other.ramp[i]),
      ],
      mapBase: c(mapBase, other.mapBase),
      pressTint: c(pressTint, other.pressTint),
    );
  }
}

/// Convenience accessors for the Odyssey design tokens and type roles.
extension OdysseyTokenLookup on BuildContext {
  /// The Odyssey design tokens for the active theme.
  ///
  /// Falls back to the dark set if the extension is missing, which only
  /// happens inside a bare `MaterialApp` in a test.
  OdysseyTokens get odyssey =>
      Theme.of(this).extension<OdysseyTokens>() ?? OdysseyTokens.dark;
}
