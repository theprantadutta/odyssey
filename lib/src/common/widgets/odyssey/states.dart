import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'buttons.dart';
import 'chips.dart';

/// The plate both states are built around: a large rounded square holding one
/// glyph, centred above the copy.
///
/// Empty and failure are different things and the plate says which without
/// resorting to colour - this palette has no red, and a warning tint would be
/// the only saturated thing on the page. An empty plate is drawn in a dashed
/// outline, which is the same language the design already uses for a slot
/// waiting to be filled. A failure plate is solid and closed.
class _StatePlate extends StatelessWidget {
  const _StatePlate({required this.icon, required this.dashed});

  final IconData icon;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return SizedBox.square(
      dimension: AppSizes.statePlate,
      child: CustomPaint(
        painter: _PlatePainter(
          colour: dashed ? t.dashed : t.hairline,
          // card, not cardAlt: in the light theme cardAlt is the canvas
          // colour exactly, so a plate filled with it cannot be seen.
          fill: dashed ? null : t.card,
          dashed: dashed,
        ),
        child: Center(
          child: Icon(icon, size: AppSizes.statePlateIcon, color: t.ink3),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({
    required this.colour,
    required this.fill,
    required this.dashed,
  });

  final Color colour;
  final Color? fill;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppSizes.radiusTile),
    );

    if (fill != null) {
      canvas.drawRRect(rect, Paint()..color = fill!);
    }

    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.hairlineWidth;

    if (!dashed) {
      canvas.drawRRect(rect, stroke);
      return;
    }

    // Dashes are walked along the path by hand: Flutter has no dashed border,
    // and the alternatives all bring a package in for one outline.
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + AppSizes.stateDash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance = end + AppSizes.stateDashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.colour != colour || old.fill != fill || old.dashed != dashed;
}

/// The shared frame: plate, optional eyebrow, headline, body, actions.
class _StateFrame extends StatelessWidget {
  const _StateFrame({
    required this.icon,
    required this.dashed,
    required this.title,
    required this.message,
    this.eyebrow,
    this.primary,
  });

  final IconData icon;
  final bool dashed;
  final String? eyebrow;
  final String title;
  final String? message;
  final Widget? primary;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.space20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatePlate(icon: icon, dashed: dashed),
          const SizedBox(height: AppSizes.space20),

          if (eyebrow != null) ...[
            EyebrowLabel(eyebrow!),
            const SizedBox(height: AppSizes.space10),
          ],

          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.sectionHeading.copyWith(color: t.ink),
          ),

          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space8),
            ConstrainedBox(
              // Held to a comfortable measure rather than the full width: a
              // single line of explanation running the width of a tablet is
              // harder to read than the same words wrapped.
              constraints: const BoxConstraints(maxWidth: AppSizes.stateMeasure),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.rowMeta.copyWith(color: t.ink3),
              ),
            ),
          ],

          if (primary != null) ...[
            const SizedBox(height: AppSizes.space20),
            primary!,
          ],
        ],
      ),
    );
  }
}

/// What a screen shows when there is nothing in it yet.
///
/// Nothing has gone wrong here, so it does not apologise. The plate is drawn
/// dashed - an outline waiting to be filled - and where there is something the
/// user can do about it, the action is the loudest thing on screen.
class OdysseyEmptyState extends StatelessWidget {
  const OdysseyEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.auto_awesome_outlined,
    this.actionLabel,
    this.onAction,
  });

  /// The line under the headline. Usually one sentence.
  final String message;

  /// The headline. Falls back to the first sentence of [message] when a caller
  /// has not been split up yet.
  final String? title;

  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final split = _split(title, message);

    return _StateFrame(
      icon: icon,
      dashed: true,
      title: split.$1,
      message: split.$2,
      primary: actionLabel == null
          ? null
          : PillButton(
              label: actionLabel!,
              onPressed: onAction,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space24,
                vertical: 15,
              ),
              expand: false,
            ),
    );
  }

  /// Splits 'No plans yet. Days fill up one idea at a time.' into a headline
  /// and a body when the caller gave one string for both.
  static (String, String?) _split(String? title, String message) {
    if (title != null) return (title, message);

    final stop = message.indexOf('. ');
    if (stop <= 0) return (message, null);
    return (message.substring(0, stop), message.substring(stop + 2));
  }
}

/// What a screen shows when it could not load.
///
/// There is no red in this palette, so failure is carried by the copy and by a
/// closed, solid plate rather than by an alarm colour. The retry is a real
/// button: it is the only thing the user can usefully do, and as a text link it
/// read as a footnote.
class OdysseyErrorState extends StatelessWidget {
  const OdysseyErrorState({
    super.key,
    required this.message,
    this.title = 'That did not load.',
    this.icon = Icons.cloud_off_rounded,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  /// What went wrong. Often an exception's own words, so it is set quietly,
  /// under a headline that says the useful part in plain English.
  final String message;

  final String title;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return _StateFrame(
      icon: icon,
      dashed: false,
      eyebrow: 'Something went wrong',
      title: title,
      message: message,
      primary: onRetry == null
          ? null
          : PillButton(
              label: retryLabel,
              onPressed: onRetry,
              style: PillStyle.card,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space24,
                vertical: 15,
              ),
              expand: false,
            ),
    );
  }
}
