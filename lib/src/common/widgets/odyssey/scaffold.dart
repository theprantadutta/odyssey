import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'buttons.dart';

/// The screen shell for this design system.
///
/// Every screen paints the canvas edge to edge and runs its content *under*
/// the status bar — the first row sits at [AppSizes.contentTop] from the
/// physical top of the screen, not from the safe-area inset. That is why this
/// does not wrap its body in a `SafeArea`.
///
/// Set [extendBehindNav] on the four screens that carry the floating nav so
/// their scroll content passes beneath the glass.
class OdysseyScaffold extends StatelessWidget {
  const OdysseyScaffold({
    super.key,
    required this.body,
    this.bottomBar,
    this.extendBehindNav = false,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;

  /// A sticky footer — the floating nav, or a screen's own CTA.
  final Widget? bottomBar;

  final bool extendBehindNav;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Scaffold(
      backgroundColor: backgroundColor ?? t.canvas,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBehindNav,
      extendBodyBehindAppBar: true,
      body: body,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// The header row most screens open with: a back circle, a centred mono-ish
/// caption, and a trailing affordance.
///
/// The spacer on the trailing side keeps the caption optically centred when
/// there is no trailing button.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    this.title,
    this.onBack,
    this.trailing,
    this.leadingGlyph = '←',
    this.showBack = true,
  });

  /// The small centred caption — "Kyoto · packing", "Step 2 of 3".
  final String? title;

  final VoidCallback? onBack;
  final Widget? trailing;
  final String leadingGlyph;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Row(
      children: [
        if (showBack)
          CircleButton(
            glyph: leadingGlyph,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            size: AppSizes.circleAction,
            semanticLabel: 'Back',
          )
        else
          const SizedBox(width: AppSizes.circleAction),
        Expanded(
          child: title == null
              ? const SizedBox.shrink()
              : Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: t.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
        trailing ?? const SizedBox(width: AppSizes.circleAction),
      ],
    );
  }
}

/// A sticky footer that fades the canvas up behind its button, so scrolling
/// content dissolves rather than being cut off — the create-trip CTA.
class StickyFooter extends StatelessWidget {
  const StickyFooter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSizes.screenPadding,
      AppSizes.space14,
      AppSizes.screenPadding,
      30,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.canvas.withValues(alpha: 0), t.canvas],
          stops: const [0, 0.38],
        ),
      ),
      child: child,
    );
  }
}

/// A user avatar.
///
/// Dark theme renders a lime gradient disc; light theme renders a flat
/// obsidian disc with the initial picked out in lime. That asymmetry is
/// deliberate — it is the accent-inversion rule applied to a face.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.name,
    this.size = AppSizes.circleNotification,
    this.imageUrl,
    this.onTap,
  });

  final String? name;
  final double size;
  final String? imageUrl;
  final VoidCallback? onTap;

  String get _initial {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: t.isDark ? AppColors.darkAvatarGradient : null,
        color: t.isDark ? null : AppColors.obsidian,
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? null
          : Text(
              _initial,
              style: AppTypography.avatarInitial.copyWith(
                fontSize: size * 0.37,
                color: t.isDark ? AppColors.obsidian : AppColors.accent,
              ),
            ),
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
