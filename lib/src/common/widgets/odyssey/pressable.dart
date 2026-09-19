import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';

/// The press behaviour shared by every tappable surface in the design.
///
/// Odyssey 2.0 has no ink ripples — Material's splash would spill colour over
/// carefully tuned translucent surfaces. Instead a press scales the target to
/// 0.98 over 90ms and, optionally, lays a faint tint over it.
///
/// Wrap whatever you want tappable:
///
/// ```dart
/// Pressable(
///   onTap: () => context.push(route),
///   borderRadius: BorderRadius.circular(AppSizes.radiusRow),
///   child: const _TripRow(),
/// )
/// ```
///
/// Honours the platform's reduced-motion setting: the scale is dropped and
/// only the tint remains, per the design's motion notes.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.tint = true,
    this.scale = AppSizes.pressScale,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Corner radius of the tint overlay. Match the child's own radius or the
  /// tint will square off its corners.
  final BorderRadius? borderRadius;

  /// Whether to lay [OdysseyTokens.pressTint] over the child while held. Turn
  /// this off for targets that already change colour on press, such as a
  /// filled button.
  final bool tint;

  final double scale;
  final HitTestBehavior behavior;
  final String? semanticLabel;

  /// Forwarded to [Semantics] so a chip or tab announces its state.
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(bool value) {
    if (!_enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tokens = Theme.of(context);
    final pressTint = tokens.highlightColor;

    Widget result = widget.child;

    if (widget.tint) {
      result = Stack(
        children: [
          result,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _down ? 1 : 0,
                duration: AppSizes.durationPress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pressTint,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!reduceMotion) {
      result = AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppSizes.durationPress,
        curve: AppSizes.curveState,
        child: result,
      );
    }

    return Semantics(
      button: _enabled,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: result,
      ),
    );
  }
}

/// Guarantees a tap target of at least [AppSizes.minTouchTarget] without
/// changing how large the child *looks*.
///
/// The design draws a lot of 36–40px circles. They read correctly at that
/// size, but a 40px target fails the accessibility floor, so the hit area is
/// padded out around them.
class TapTarget extends StatelessWidget {
  const TapTarget({
    super.key,
    required this.child,
    this.size = AppSizes.minTouchTarget,
  });

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(child: child),
    );
  }
}
