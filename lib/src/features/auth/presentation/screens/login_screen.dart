import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/utils/validators.dart';
import '../../../../common/widgets/odyssey/dialogs.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Sign in — screen 3b.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.onRegisterTap});

  final VoidCallback? onRegisterTap;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    try {
      await ref
          .read(authProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        showOdysseyMessage(context, e.toString());
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final needsLinking = await ref
          .read(authProvider.notifier)
          .signInWithGoogle();
      if (needsLinking && mounted) {
        await showAccountLinkingSheet(context: context, ref: ref);
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        showOdysseyMessage(context, e.toString());
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      final needsLinking = await ref
          .read(authProvider.notifier)
          .signInWithApple();
      if (needsLinking && mounted) {
        await showAccountLinkingSheet(
          context: context,
          ref: ref,
          providerName: 'Apple',
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        showOdysseyMessage(context, e.toString());
      }
    }
  }

  /// Sign in with Apple is only offered on Apple platforms.
  bool get _showAppleButton =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final authState = ref.watch(authProvider);
    final isBusy =
        authState.isLoading ||
        authState.isGoogleLoading ||
        authState.isAppleLoading;

    return AuthScaffold(
      headline: 'Welcome\nback.',
      subtitle: 'Sign in and pick the journey back up.',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldCard(
              label: 'Email',
              controller: _emailController,
              focusNode: _emailFocusNode,
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
            ),
            const SizedBox(height: AppSizes.space12),
            FieldCard(
              label: 'Password',
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              hint: '••••••••',
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: Validators.password,
              onSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: AppSizes.space12),
            Align(
              alignment: Alignment.centerRight,
              child: Pressable(
                onTap: () => showOdysseyMessage(
                  context,
                  'Password reset is coming. Sign in with Google or Apple in '
                  'the meantime.',
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space8,
                    vertical: AppSizes.space4,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTypography.caption.copyWith(color: t.ink2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space20),
            // Lime in both themes here, matching the onboarding call to
            // action — this is still the brand's way in.
            PillButton(
              label: 'Sign in',
              style: PillStyle.brand,
              isLoading: authState.isLoading,
              onPressed: isBusy ? null : _handleLogin,
            ),
          ],
        ),
      ),
      onGoogle: isBusy ? null : _handleGoogleSignIn,
      onApple: _showAppleButton ? (isBusy ? null : _handleAppleSignIn) : null,
      googleLoading: authState.isGoogleLoading,
      appleLoading: authState.isAppleLoading,
      footerPrompt: 'New here? ',
      footerAction: 'Create an account',
      onFooterTap: widget.onRegisterTap,
    );
  }
}
