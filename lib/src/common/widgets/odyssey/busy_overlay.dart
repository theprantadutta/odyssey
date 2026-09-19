import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'brand_mark.dart';

/// A full-screen wait, for the stretches where the app is doing something the
/// user cannot see and must not interrupt.
///
/// The design bans spinners outside a button submit, and a button spinner is
/// the wrong instrument here anyway: after the Google sheet closes the account
/// is still being created on the server, and a 16px ring inside a button reads
/// as nothing at all. So the whole screen says what is happening instead.
///
/// It also swallows input, which is the point — the work in flight ends in a
/// route change, and a second tap on the way there is a second sign-in.
class BusyOverlay extends StatelessWidget {
  const BusyOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.label,
  });

  final bool visible;

  /// What is happening, in the user's terms — 'Setting up your account'.
  final String? label;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Stack(
      // Passthrough, not the default loose fit, so the child keeps whatever
      // constraints this widget was handed.
      fit: StackFit.passthrough,
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                // Nearly opaque rather than a light scrim: the screen behind
                // is a form the user is done with, and half-seeing it while
                // they wait invites another tap.
                color: t.canvas.withValues(alpha: 0.94),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OdysseyMark(size: AppSizes.markWait),
                      const SizedBox(height: AppSizes.space24),
                      if (label != null) ...[
                        Text(
                          label!,
                          textAlign: TextAlign.center,
                          style: AppTypography.rowTitle.copyWith(color: t.ink),
                        ),
                        const SizedBox(height: AppSizes.space16),
                      ],
                      const _WaitTrack(),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The indeterminate counterpart to [ProgressTrack]: a hairline track with a
/// short segment sweeping across it, in the accent.
///
/// Indeterminate because there is nothing honest to measure — the wait is a
/// network round trip, not a known number of steps.
class _WaitTrack extends StatefulWidget {
  const _WaitTrack();

  @override
  State<_WaitTrack> createState() => _WaitTrackState();
}

class _WaitTrackState extends State<_WaitTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppSizes.durationWaitSweep,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    // Reduced motion gets a still track rather than a stuttering one; the
    // label above already carries the message.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return _track(t.hairlineStrong, null);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _track(t.hairlineStrong, _controller.value),
    );
  }

  Widget _track(Color trackColor, double? progress) {
    final t = context.odyssey;

    return SizedBox(
      width: AppSizes.waitTrackWidth,
      height: AppSizes.waitTrackHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.waitTrackHeight / 2),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trackColor)),
            if (progress != null)
              Align(
                // -1 to 1 across the track, so the segment runs off one end and
                // back on at the other rather than bouncing.
                alignment: Alignment(progress * 4 - 2, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.35,
                  child: ColoredBox(
                    color: t.action,
                    child: const SizedBox(
                      height: AppSizes.waitTrackHeight,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
