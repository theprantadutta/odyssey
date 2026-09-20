import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import '../../utils/avatar_photo.dart';
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
    this.topFade = true,
  });

  final Widget body;

  /// A sticky footer — the floating nav, or a screen's own CTA.
  final Widget? bottomBar;

  final bool extendBehindNav;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  /// Fades the canvas in behind the status bar.
  ///
  /// Content starts *under* the overlaid status bar in this design, which is
  /// fine at rest — the first row sits at 62px, well clear of it. It stops
  /// being fine once the screen scrolls: without this, headings run straight
  /// under the clock. The fade is the same device the sticky footer uses at
  /// the other end.
  ///
  /// Turn it off for a screen that puts a photograph under the status bar on
  /// purpose, where the scrim is already doing this job.
  final bool topFade;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Scaffold(
      backgroundColor: backgroundColor ?? t.canvas,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBehindNav,
      extendBodyBehindAppBar: true,
      body: topFade
          ? Stack(
              children: [
                body,
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: StatusBarFade(color: backgroundColor ?? t.canvas),
                ),
              ],
            )
          : body,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// The canvas fading out from under the status bar, so scrolling content does
/// not collide with the clock on a design that has no app bars.
class StatusBarFade extends StatelessWidget {
  const StatusBarFade({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.viewPaddingOf(context).top + AppSizes.space14;

    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color, color.withValues(alpha: 0)],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
      ),
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

    final initial = Text(
      _initial,
      style: AppTypography.avatarInitial.copyWith(
        fontSize: size * 0.37,
        color: t.isDark ? AppColors.obsidian : AppColors.accent,
      ),
    );

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: t.isDark ? AppColors.darkAvatarGradient : null,
        color: t.isDark ? null : AppColors.obsidian,
      ),
      // The initial stays underneath the picture rather than being replaced by
      // it. A DecorationImage has no error path, so a photo that 404s or a
      // device that is offline left an empty coloured disc with nothing in it;
      // this way the letter is what shows until the image arrives, and what
      // comes back if it never does.
      child: !hasImage
          ? initial
          : ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: initial),
                  _ProviderPhoto(url: imageUrl!),
                ],
              ),
            ),
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}

/// The account picture from Google or Apple, shown only when it is one.
///
/// Every Google account has a picture, but for an account that never uploaded
/// one it is a generated monogram - a flat tile in Google's palette with the
/// first letter on it. Dropped into this design it is the only unbranded colour
/// on the page, and it carries no more information than the initial already
/// underneath it. So the bytes are looked at before the image is shown, and a
/// monogram is left off in favour of Odyssey's own. See [AvatarPhoto].
class _ProviderPhoto extends StatefulWidget {
  const _ProviderPhoto({required this.url});

  final String url;

  /// Verdicts by URL, so an avatar that appears on several screens - and in a
  /// list - is judged once per run rather than once per build.
  static final Map<String, bool> _isPhoto = {};

  @override
  State<_ProviderPhoto> createState() => _ProviderPhotoState();
}

class _ProviderPhotoState extends State<_ProviderPhoto> {
  bool? _show;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(_ProviderPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _show = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final cached = _ProviderPhoto._isPhoto[widget.url];
    if (cached != null) {
      setState(() => _show = cached);
      return;
    }

    var verdict = true;
    try {
      // The same provider CachedNetworkImage will use below, so deciding this
      // does not cost a second download.
      final bytes = await _decode(CachedNetworkImageProvider(widget.url));
      if (bytes != null) {
        verdict = !AvatarPhoto.looksGenerated(
          bytes.$1,
          width: bytes.$2,
          height: bytes.$3,
        );
      }
    } catch (_) {
      // Unreadable for any reason: show it. An avatar is not worth failing on,
      // and CachedNetworkImage has its own error path below.
      verdict = true;
    }

    _ProviderPhoto._isPhoto[widget.url] = verdict;
    if (mounted) setState(() => _show = verdict);
  }

  static Future<(Uint8List, int, int)?> _decode(ImageProvider provider) {
    final completer = Completer<(Uint8List, int, int)?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (image, _) async {
        stream.removeListener(listener);
        try {
          final data = await image.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          completer.complete(
            data == null
                ? null
                : (
                    data.buffer.asUint8List(),
                    image.image.width,
                    image.image.height,
                  ),
          );
        } catch (_) {
          completer.complete(null);
        }
      },
      onError: (_, _) {
        stream.removeListener(listener);
        completer.complete(null);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    // Undecided, or decided against: the initial underneath is what shows.
    if (_show != true) return const SizedBox.shrink();

    return CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.cover,
      fadeInDuration: AppSizes.durationFast,
      placeholder: (_, _) => const SizedBox.shrink(),
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
