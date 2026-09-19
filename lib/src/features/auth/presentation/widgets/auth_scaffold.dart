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

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: t.canvas,
      body: SingleChildScrollView(
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
                      style: AppTypography.monoDivider.copyWith(color: t.ink3),
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
                        icon: Icons.apple,
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
                        icon: Icons.g_mobiledata_rounded,
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
    );
  }
}

/// One of the two equal social buttons: a card box with a 16px mark and a
/// label, rather than a branded pill.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
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
              Icon(icon, size: 16, color: t.ink3),
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
    if (context.mounted) showOdysseyMessage(context, e.toString());
  }
}
