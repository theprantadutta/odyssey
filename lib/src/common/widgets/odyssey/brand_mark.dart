import 'package:flutter/material.dart';

import '../../theme/odyssey_tokens.dart';

/// Which colourway of the waypoint mark to draw.
enum MarkTone {
  /// Lime. Only on a dark surface — the brand kit is explicit that lime on a
  /// light background fails contrast.
  lime,

  /// Ink. The mark on light surfaces.
  ink,

  /// Paper. The mono mark for photography.
  white,

  /// Resolves to lime on a dark canvas and ink on a light one.
  auto,
}

/// The Odyssey waypoint mark.
///
/// A rounded square rotated 45° with one sharpened corner and a knocked-out
/// centre, from the Waypoint brand kit. It is shipped as transparent PNGs at
/// three sizes per tone; this picks the smallest one that still covers the
/// requested size at the current device pixel ratio.
///
/// The kit's rules are enforced here rather than left to call sites: the mark
/// is always square, never tinted to another colour, and never rendered lime
/// on a light background. Below 16px use a plain lime dot instead of this.
class OdysseyMark extends StatelessWidget {
  const OdysseyMark({
    super.key,
    this.size = 48,
    this.tone = MarkTone.auto,
  });

  final double size;
  final MarkTone tone;

  /// The asset ladder. 96 covers most in-app use, 192 the splash and empty
  /// states, 512 anything that fills a screen.
  static const _steps = [96, 192, 512];

  String _assetFor(MarkTone resolved, double devicePixelRatio) {
    final needed = size * devicePixelRatio;
    final step = _steps.firstWhere(
      (s) => s >= needed,
      orElse: () => _steps.last,
    );
    return 'assets/brand/mark/mark-${resolved.name}-$step.png';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final resolved = tone == MarkTone.auto
        ? (t.isDark ? MarkTone.lime : MarkTone.ink)
        : tone;

    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;

    return Semantics(
      label: 'Odyssey',
      image: true,
      child: Image.asset(
        _assetFor(resolved, dpr),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
