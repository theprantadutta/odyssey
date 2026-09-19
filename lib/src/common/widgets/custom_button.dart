import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/odyssey_tokens.dart';
import 'odyssey/buttons.dart';
import 'odyssey/pressable.dart';
import 'odyssey/surfaces.dart';

/// The pre-2.0 button API, kept so the handful of call sites that still use it
/// keep working — and re-pointed at [PillButton] so they render in the new
/// system rather than in the retired one.
///
/// New code should use [PillButton] directly; it names its variants after what
/// they mean rather than taking a colour.
@Deprecated('Use PillButton')
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.height = AppSizes.buttonHeightMd,
    this.borderRadius = AppSizes.radiusFull,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;

  /// Ignored. This system has one action colour and one accent; a button that
  /// takes an arbitrary fill is how a second accent gets back in.
  final Color? backgroundColor;

  /// Ignored, for the same reason as [backgroundColor].
  final Color? textColor;

  final IconData? icon;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return PillButton(
      label: text,
      onPressed: onPressed,
      isLoading: isLoading,
      style: isOutlined ? PillStyle.outline : PillStyle.action,
      icon: icon,
      padding: EdgeInsets.symmetric(vertical: (height - 20) / 2),
    );
  }
}

/// A small icon button on a soft surface.
@Deprecated('Use CircleButton or IconChip')
class SoftIconButton extends StatelessWidget {
  const SoftIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size = AppSizes.iconMd,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSizes.radiusChipSm),
      child: IconChip(
        icon: icon,
        size: size + AppSizes.space16,
        iconSize: size,
        color: backgroundColor ?? t.cardAlt,
        iconColor: iconColor ?? t.ink2,
      ),
    );
  }
}

/// The old floating action button.
///
/// Odyssey 2.0 has no FABs — an action that matters enough for one belongs in
/// the screen's header or its sticky footer, where it does not sit on top of
/// the content. This renders as a circular action button so the remaining call
/// sites stay on-system.
@Deprecated('Put the action in the screen header or a sticky footer')
class GoldFAB extends StatelessWidget {
  const GoldFAB({
    super.key,
    required this.icon,
    this.onPressed,
    this.label,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return CircleButton(
      icon: icon,
      style: CircleStyle.action,
      size: AppSizes.circleIntroArrow,
      onPressed: onPressed,
      semanticLabel: label,
    );
  }
}
