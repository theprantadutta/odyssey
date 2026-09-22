import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../providers/auth_provider.dart';

/// The shared frame behind sign-in and register — screens 3b and its sibling.
///
/// Single column, 24px gutters, no hero image: a back circle, the headline set
/// very large and broken across two lines, the caller's form, the `OR`
/// divider, the social row, and the footer.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.headline,
    required this.subtitle,
    required this.form,
    this.onGoogle,
    this.onApple,
    this.googleLoading = false,
    this.appleLoading = false,
    this.footerPrompt,
    this.footerAction,
    this.onFooterTap,
    this.onBack,
    this.extra,
    this.busy = false,
    this.busyLabel,
  });

  final String headline;
  final String subtitle;
  final Widget form;

  final VoidCallback? onGoogle;

  /// Null on platforms where Sign in with Apple is not offered.
  final VoidCallback? onApple;

  final bool googleLoading;
  final bool appleLoading;

  final String? footerPrompt;
  final String? footerAction;
  final VoidCallback? onFooterTap;
  final VoidCallback? onBack;

  /// Anything that belongs between the form and the divider — the register
  /// screen's terms line.
  final Widget? extra;

  /// Blanks the screen behind a [BusyOverlay]. This covers the stretch after a
  /// social sheet closes, when the account is still being created server-side
  /// and nothing on the form moves.
  final bool busy;

  /// What the wait is for. See [BusyOverlay.label].
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: t.canvas,
      body: BusyOverlay(
        visible: busy,
        label: busyLabel,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.authPadding,
            AppSizes.contentTop,
            AppSizes.authPadding,
            34,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canPop || onBack != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleButton(
                    glyph: '←',
                    size: AppSizes.circleBack,
                    glyphSize: 18,
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    semanticLabel: 'Back',
                  ),
                ),
              const SizedBox(height: AppSizes.space24),
              Text(
                headline,
                style: AppTypography.screenTitle.copyWith(
                  fontSize: 38,
                  letterSpacing: -1.71,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: AppSizes.space12),
              Text(
                subtitle,
                style: AppTypography.subtitle.copyWith(color: t.ink2),
              ),
              const SizedBox(height: AppSizes.space32),
              form,
              if (extra != null) ...[
                const SizedBox(height: AppSizes.space16),
                extra!,
              ],

              if (onGoogle != null || onApple != null) ...[
                const SizedBox(height: AppSizes.space26),
                Row(
                  children: [
                    Expanded(child: Divider(color: t.hairline, height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space14,
                      ),
                      child: Text(
                        'OR',
                        style: AppTypography.monoDivider.copyWith(
                          color: t.ink3,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: t.hairline, height: 1)),
                  ],
                ),
                const SizedBox(height: AppSizes.space20),
                Row(
                  children: [
                    if (onApple != null) ...[
                      Expanded(
                        child: _SocialButton(
                          label: 'Apple',
                          mark: const Icon(Icons.apple, size: 16),
                          loading: appleLoading,
                          onTap: onApple,
                        ),
                      ),
                      const SizedBox(width: AppSizes.space10),
                    ],
                    if (onGoogle != null)
                      Expanded(
                        child: _SocialButton(
                          label: 'Google',
                          mark: const _GoogleMark(),
                          loading: googleLoading,
                          onTap: onGoogle,
                        ),
                      ),
                  ],
                ),
              ],

              if (footerPrompt != null && footerAction != null) ...[
                const SizedBox(height: AppSizes.space26),
                Center(
                  child: Pressable(
                    onTap: onFooterTap,
                    borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.space12,
                        vertical: AppSizes.space6,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: footerPrompt,
                          style: AppTypography.pill.copyWith(
                            fontSize: 12.5,
                            color: t.ink3,
                          ),
                          children: [
                            TextSpan(
                              text: footerAction,
                              style: AppTypography.caption.copyWith(
                                fontSize: 12.5,
                                color: t.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two equal social buttons: a card box with a 16px mark and a
/// label, rather than a branded pill.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.mark,
    required this.onTap,
    this.loading = false,
  });

  final String label;

  /// The 16px brand mark. Colour comes from the ambient [IconTheme] below, so
  /// the mark stays in `ink3` with the rest of the design's monochrome set.
  final Widget mark;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Pressable(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      semanticLabel: 'Continue with $label',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
          border: Border.all(color: t.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(t.ink3),
                ),
              )
            else
              IconTheme(
                data: IconThemeData(size: 16, color: t.ink3),
                child: mark,
              ),
            const SizedBox(width: 9),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 12.5,
                color: t.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offered when a social sign-in lands on an email that already has a
/// password account, so the two can be joined rather than collide.
Future<void> showAccountLinkingSheet({
  required BuildContext context,
  required WidgetRef ref,
  String providerName = 'Google',
}) async {
  final link = await showOdysseyConfirm(
    context: context,
    title: 'Link account',
    body: [
      'An account with this email already exists. Linking lets you sign in '
          'with $providerName from now on, keeping everything you have saved.',
    ],
    confirmLabel: 'Link account',
    cancelLabel: 'Not now',
  );

  if (!link) {
    ref.read(authProvider.notifier).cancelAccountLinking();
    return;
  }

  try {
    await ref.read(authProvider.notifier).autoLinkGoogleAccount();
  } catch (e) {
    if (context.mounted) showOdysseyError(context, 'That did not work. Please try again.', error: e);
  }
}

/// The Google mark, drawn rather than set in type.
///
/// `Icons.g_mobiledata_rounded` is a letter, and at 16px on a sign-in button it
/// reads as a stray character rather than a brand. This is the mark's actual
/// silhouette: a ring broken at three o'clock with a bar running in to the
/// centre. It stays monochrome because the design admits one accent and no
/// other colour — the handoff draws both social marks as neutral `ink3` shapes.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final size = icon.size ?? 16;

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GoogleMarkPainter(icon.color ?? const Color(0xFF8A8F98)),
      ),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn against a 16px square and scaled, so the proportions hold at any
    // size the button asks for.
    final scale = size.width / 16;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 6 * scale;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    // From three o'clock, most of the way round — the gap sits above the bar,
    // which is what makes a G out of a ring.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      300 * math.pi / 180,
      false,
      paint,
    );

    // The bar, running from the centre out to where the arc begins.
    canvas.drawLine(
      center.translate(0.6 * scale, 0),
      center.translate(radius, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
