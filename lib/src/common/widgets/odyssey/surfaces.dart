import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'pressable.dart';

/// The standard card surface: the translucent [OdysseyTokens.card] fill, a 1px
/// hairline, and a rounded corner. No shadow — depth in this system comes from
/// the border and the fill alone.
class OdysseyCard extends StatelessWidget {
  const OdysseyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.space16),
    this.radius = AppSizes.radiusRow,
    this.color,
    this.borderColor,
    this.onTap,
    this.margin,
    this.width,
    this.height,
    this.bordered = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Overrides the card fill — pass [OdysseyTokens.accentTint] for a "done"
  /// row, or [OdysseyTokens.cardAlt] for the heavier variant.
  final Color? color;

  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final borderRadius = BorderRadius.circular(radius);

    Widget card = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.card,
        borderRadius: borderRadius,
        border: bordered
            ? Border.all(color: borderColor ?? t.hairline)
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      card = Pressable(
        onTap: onTap,
        borderRadius: borderRadius,
        child: card,
      );
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }
}

/// A single card containing several rows separated by 1px [OdysseyTokens
/// .separator] lines — the settings groups, and any list that reads as one
/// object rather than a stack of cards.
///
/// The first row gets no divider above it.
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.radius = AppSizes.radiusPanel,
    this.color,
  });

  final List<Widget> children;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final rows = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: AppSizes.hairlineWidth,
          thickness: AppSizes.hairlineWidth,
          color: t.separator,
        ));
      }
      rows.add(children[i]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: color ?? t.card,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: t.hairline),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// A floating bar that blurs whatever scrolls beneath it.
///
/// The design specifies `backdrop-filter: blur(18px)` over a translucent fill;
/// CSS blur radius is roughly twice the Gaussian sigma, so this uses sigma 9.
///
/// Used by the bottom nav and the selected-pin card on the map.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.radius = AppSizes.radiusFull,
    this.padding = const EdgeInsets.all(AppSizes.space8),
    this.blur = AppSizes.glassBlur,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: t.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor ?? t.hairlineStrong),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A lime tile. The one place the two themes agree: the hero stat tiles stay
/// `#D6FF3D` with obsidian text in light *and* dark, which keeps the brand
/// moment constant.
///
/// Optionally bleeds a faint decorative circle off one corner, as the points,
/// packing and statistics heroes do.
class HeroTile extends StatelessWidget {
  const HeroTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSizes.space22),
    this.radius = AppSizes.radiusHero,
    this.decorCorner = Alignment.topRight,
    this.showDecor = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Which corner the decorative circle bleeds off.
  final Alignment decorCorner;
  final bool showDecor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    Widget tile = ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: borderRadius,
        ),
        child: Stack(
          children: [
            if (showDecor)
              Positioned(
                right: decorCorner.x > 0 ? -50 : null,
                left: decorCorner.x < 0 ? -50 : null,
                top: decorCorner.y < 0 ? -50 : null,
                bottom: decorCorner.y > 0 ? -50 : null,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: AppColors.onAccentDecor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap != null) {
      tile = Pressable(
        onTap: onTap,
        borderRadius: borderRadius,
        tint: false,
        child: tile,
      );
    }
    return tile;
  }
}

/// A photographic surface — the hero covers, trip thumbs, stay cards and
/// memory tiles.
///
/// Renders [imageUrl] when there is one and falls back to a placeholder
/// gradient keyed off [seed], so a trip with no cover still gets a stable,
/// on-brand surface rather than a grey box.
///
/// [scrim] lays the standard dark-to-clear-to-dark wash under any [child],
/// which is what lets text over a photo stay the light-on-dark set in both
/// themes.
class PhotoSurface extends StatelessWidget {
  const PhotoSurface({
    super.key,
    this.imageUrl,
    this.seed = '',
    this.gradient,
    this.child,
    this.radius = AppSizes.radiusTile,
    this.height,
    this.width,
    this.scrim = true,
    this.stripes = true,
    this.onTap,
    this.heroTag,
  });

  final String? imageUrl;

  /// Seeds the placeholder gradient so the same entity always renders the same
  /// colours. Pass the trip or memory id.
  final String seed;

  /// Forces a specific placeholder gradient, overriding [seed].
  final LinearGradient? gradient;

  final Widget? child;
  final double radius;
  final double? height;
  final double? width;
  final bool scrim;

  /// The diagonal stripe overlay from the mocks. It reads as texture on a flat
  /// gradient; keep it off when a real photograph is showing.
  final bool stripes;

  final VoidCallback? onTap;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final fallback = gradient ?? AppColors.gradientFor(seed);

    Widget surface = ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: AppSizes.durationState,
                placeholder: (_, _) =>
                    DecoratedBox(decoration: BoxDecoration(gradient: fallback)),
                errorWidget: (_, _, _) =>
                    DecoratedBox(decoration: BoxDecoration(gradient: fallback)),
              )
            else
              DecoratedBox(decoration: BoxDecoration(gradient: fallback)),

            // Texture only belongs on the placeholder — a real photograph
            // already carries its own detail.
            if (stripes && !hasImage)
              const _StripeOverlay(),

            if (scrim)
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.photoScrim),
              ),

            ?child,
          ],
        ),
      ),
    );

    if (heroTag != null) {
      surface = Hero(tag: heroTag!, child: surface);
    }

    if (onTap != null) {
      surface = Pressable(
        onTap: onTap,
        borderRadius: borderRadius,
        tint: false,
        child: surface,
      );
    }

    return surface;
  }
}

/// The diagonal hairline stripes laid over a placeholder gradient.
class _StripeOverlay extends StatelessWidget {
  const _StripeOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StripePainter(), size: Size.infinite);
  }
}

class _StripePainter extends CustomPainter {
  /// 2px line every 14px at 112°, matching the mocks' repeating gradient.
  static const double _angle = 112 * 3.1415926535 / 180;
  static const double _spacing = 14;
  static const double _width = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = _width;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // Rotate about the centre and draw far enough past the edges that the
    // stripes still cover the box once it is turned.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(_angle);
    final extent = size.width + size.height;

    for (var x = -extent; x < extent; x += _spacing) {
      canvas.drawLine(Offset(x, -extent), Offset(x, extent), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) => false;
}

/// The `photo · kyoto autumn` tag that sits in the corner of a placeholder
/// image. Mono, lowercase, on a dark translucent pill.
///
/// This marks an image as a stand-in. Once real photography is flowing it
/// should disappear — pass `showTag: false` or simply stop rendering it.
class PhotoTag extends StatelessWidget {
  const PhotoTag(this.label, {super.key, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.photoTagBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.photoTagBorder),
      ),
      child: Text(
        label,
        style: AppTypography.photoTag.copyWith(color: AppColors.onPhoto3),
      ),
    );
  }
}

/// A pill that floats on a photo — the home hero's "14 days out" countdown.
class PhotoPill extends StatelessWidget {
  const PhotoPill({
    super.key,
    required this.label,
    this.dotColor = AppColors.accent,
    this.showDot = true,
  });

  final String label;
  final Color dotColor;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.photoChipBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: AppColors.photoTagBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSizes.space6),
          ],
          Text(
            label,
            style: AppTypography.countdown.copyWith(color: AppColors.onPhoto),
          ),
        ],
      ),
    );
  }
}

/// A dashed-border box — the empty-state and "add something" affordance.
///
/// Used as a full-width pill ("Add to this day", "Upload a document") and as a
/// grid tile ("Add photo").
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.radius = AppSizes.radiusFull,
    this.padding = const EdgeInsets.all(AppSizes.space16),
    this.onTap,
    this.height,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    Widget box = CustomPaint(
      painter: _DashedBorderPainter(color: t.dashed, radius: radius),
      child: Container(
        height: height,
        padding: padding,
        alignment: Alignment.center,
        child: child,
      ),
    );

    if (onTap != null) {
      box = Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: box,
      );
    }
    return box;
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.hairlineWidth;

    final effective = radius >= AppSizes.radiusFull
        ? size.height / 2
        : radius;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(effective),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

/// The raised panel that overlaps a hero cover on the trip detail screen.
///
/// Rounded on its top corners only, filled with [OdysseyTokens.sheet], and
/// pulled up over the image by [AppSizes.sheetOverlap].
class OverlapSheet extends StatelessWidget {
  const OverlapSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      AppSizes.space22,
      AppSizes.screenPadding,
      AppSizes.scrollBottom,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Transform.translate(
      offset: const Offset(0, AppSizes.sheetOverlap),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: t.sheet,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusSheet),
          ),
          border: Border(top: BorderSide(color: t.hairline)),
        ),
        child: child,
      ),
    );
  }
}

/// A small rounded-square tile holding an icon — the settings row chips, the
/// map controls, the statistics country marks.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.size = 32,
    this.radius = AppSizes.radiusChipSm,
    this.color,
    this.iconColor,
    this.iconSize = AppSizes.iconXs,
    this.circle = false,
    this.gradient,
  });

  final IconData icon;
  final double size;
  final double radius;
  final Color? color;
  final Color? iconColor;
  final double iconSize;

  /// The settings navigation group alternates rounded-square and circular
  /// chips down the list.
  final bool circle;

  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? t.cardAlt) : null,
        gradient: gradient,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: iconColor ?? t.ink2),
    );
  }
}
