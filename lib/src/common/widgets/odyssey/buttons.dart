import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'pressable.dart';
import 'surfaces.dart';

/// Which fill a [PillButton] wears.
enum PillStyle {
  /// The theme's primary action colour — lime in dark, ink in light. This is
  /// the default and the right choice almost everywhere.
  action,

  /// Lime in *both* themes. Reserved for the auth call to action on the
  /// onboarding and sign-in screens, where the design keeps the brand colour
  /// regardless of theme.
  brand,

  /// A card fill with a hairline — the quiet secondary action.
  card,

  /// Outline only, for destructive-adjacent or low-emphasis actions such as
  /// "Sign out".
  outline,

  /// A dashed border — "Add to this day", "Upload a document".
  dashed,
}

/// The primary pill button: fully rounded, 17px of vertical padding, a Manrope
/// 14/700 label, and no shadow.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = PillStyle.action,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.expand = true,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Shows a 16px ring in the label colour. The only spinner the design
  /// permits is on button submit.
  final bool isLoading;

  /// Whether the button stretches to fill its parent.
  final bool expand;

  final EdgeInsetsGeometry? padding;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final (Color bg, Color fg, Color? border) = switch (style) {
      PillStyle.action => (t.action, t.onAction, null),
      PillStyle.brand => (AppColors.accent, AppColors.onAccent, null),
      PillStyle.card => (t.card, t.ink, t.hairlineStrong),
      PillStyle.outline => (Colors.transparent, t.ink2, t.hairline),
      PillStyle.dashed => (Colors.transparent, t.ink2, null),
    };

    final effectivePadding = padding ??
        const EdgeInsets.symmetric(vertical: AppSizes.buttonPadding);

    final labelColor = _enabled ? fg : t.ink3;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          ),
          const SizedBox(width: AppSizes.space10),
        ] else if (icon != null) ...[
          Icon(icon, size: AppSizes.iconSm, color: labelColor),
          const SizedBox(width: AppSizes.space8),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTypography.button.copyWith(color: labelColor),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSizes.space8),
          Icon(trailingIcon, size: AppSizes.iconSm, color: labelColor),
        ],
      ],
    );

    if (style == PillStyle.dashed) {
      return DashedBox(
        onTap: _enabled ? onPressed : null,
        padding: effectivePadding,
        child: content,
      );
    }

    return Pressable(
      onTap: _enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      tint: style == PillStyle.card || style == PillStyle.outline,
      semanticLabel: label,
      child: Container(
        width: expand ? double.infinity : null,
        padding: effectivePadding,
        decoration: BoxDecoration(
          // skeleton, not cardAlt, for the disabled fill: in the light theme
          // cardAlt is the canvas colour, so a disabled pill vanished into the
          // page and read as a line of grey text with no button around it.
          color: _enabled ? bg : t.skeleton,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: border != null ? Border.all(color: border) : null,
        ),
        child: content,
      ),
    );
  }
}

/// Which fill a [CircleButton] wears.
enum CircleStyle {
  /// Card fill with a hairline — back buttons, the notification bell.
  card,

  /// The primary action colour, with its glyph in [OdysseyTokens.actionGlyph].
  /// The home search button, the hero arrow, the "+" in a screen header.
  action,

  /// Lime in both themes — the edit affordance on a trip cover.
  brand,

  /// A translucent dark pill for circles that float on a photograph.
  glass,
}

/// A circular icon button. The design uses these at 36 / 38 / 40 / 42 / 44 /
/// 54 / 56px; whatever the visual size, the tap target is padded to 44px.
///
/// Pass either a [glyph] (one of the Space Grotesk marks — `←` `→` `✕` `+`)
/// or an [icon] from the app's icon set.
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    this.icon,
    this.glyph,
    this.onPressed,
    this.size = AppSizes.circleAction,
    this.style = CircleStyle.card,
    this.iconSize,
    this.glyphSize,
    this.semanticLabel,
  }) : assert(icon != null || glyph != null, 'Provide an icon or a glyph');

  final IconData? icon;
  final String? glyph;
  final VoidCallback? onPressed;
  final double size;
  final CircleStyle style;
  final double? iconSize;
  final double? glyphSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final (Color bg, Color fg, Color? border) = switch (style) {
      CircleStyle.card => (t.card, t.ink, t.hairline),
      CircleStyle.action => (t.action, t.actionGlyph, null),
      CircleStyle.brand => (AppColors.accent, AppColors.onAccent, null),
      CircleStyle.glass => (
          AppColors.photoChipBg,
          AppColors.onPhoto,
          AppColors.photoTagBorder,
        ),
    };

    final child = glyph != null
        ? Text(
            glyph!,
            style: AppTypography.glyph.copyWith(
              fontSize: glyphSize ?? size * 0.45,
              color: fg,
            ),
          )
        : Icon(icon, size: iconSize ?? size * 0.42, color: fg);

    return TapTarget(
      size: size < AppSizes.minTouchTarget ? AppSizes.minTouchTarget : size,
      child: Pressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        tint: style == CircleStyle.card,
        semanticLabel: semanticLabel,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: border != null ? Border.all(color: border) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A rounded-square icon button — the map's zoom and locate controls.
class SquareButton extends StatelessWidget {
  const SquareButton({
    super.key,
    this.icon,
    this.glyph,
    this.onPressed,
    this.size = AppSizes.circleAction,
    this.radius = AppSizes.radiusChip,
    this.accent = false,
    this.semanticLabel,
  }) : assert(icon != null || glyph != null, 'Provide an icon or a glyph');

  final IconData? icon;
  final String? glyph;
  final VoidCallback? onPressed;
  final double size;
  final double radius;

  /// Fills with lime and uses the on-lime glyph colour.
  final bool accent;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final bg = accent ? AppColors.accent : t.glass;
    final fg = accent ? AppColors.onAccent : t.ink;

    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      tint: !accent,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: accent ? null : Border.all(color: t.hairlineStrong),
        ),
        child: glyph != null
            ? Text(
                glyph!,
                style: AppTypography.glyph.copyWith(
                  fontSize: size * 0.42,
                  color: fg,
                ),
              )
            : Icon(icon, size: AppSizes.iconSm, color: fg),
      ),
    );
  }
}

/// The trailing arrow that ends a hero card or a list row: a filled circle
/// carrying a `→`.
class ArrowCircle extends StatelessWidget {
  const ArrowCircle({
    super.key,
    this.size = AppSizes.circleHeroArrow,
    this.onTap,
    this.brand = false,
  });

  final double size;
  final VoidCallback? onTap;

  /// Lime in both themes rather than following the inversion rule. The home
  /// hero's arrow sits on a photograph, where the theme's ink fill would
  /// vanish.
  final bool brand;

  @override
  Widget build(BuildContext context) {
    return CircleButton(
      glyph: '→',
      onPressed: onTap,
      size: size,
      style: brand ? CircleStyle.brand : CircleStyle.action,
      glyphSize: size * 0.39,
      semanticLabel: 'Open',
    );
  }
}
