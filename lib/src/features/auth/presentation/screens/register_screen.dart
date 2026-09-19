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

/// Create an account — the sibling of screen 3b, built on the same frame.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.onLoginTap});

  final VoidCallback? onLoginTap;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    try {
      final name = _nameController.text.trim();
      await ref
          .read(authProvider.notifier)
          .register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            displayName: name.isNotEmpty ? name : null,
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
      headline: 'Start the\njournal.',
      subtitle: 'One account holds every trip you take.',
      // Creating the account server-side takes a couple of seconds after
      // the Google sheet closes, with nothing on the form to show for it.
      busy: isBusy,
      busyLabel: 'Setting up your account',
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldCard(
              label: 'Name',
              controller: _nameController,
              focusNode: _nameFocusNode,
              hint: 'What should we call you?',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (value) =>
                  Validators.required(value, fieldName: 'Name'),
              onSubmitted: (_) => _emailFocusNode.requestFocus(),
            ),
            const SizedBox(height: AppSizes.space12),
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
              hint: 'At least 8 characters',
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.password,
              onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
            ),
            const SizedBox(height: AppSizes.space12),
            FieldCard(
              label: 'Confirm password',
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              hint: 'Type it again',
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (value) => Validators.confirmPassword(
                value,
                _passwordController.text,
              ),
              onSubmitted: (_) => _handleRegister(),
            ),
            const SizedBox(height: AppSizes.space20),
            PillButton(
              label: 'Create account',
              style: PillStyle.brand,
              isLoading: authState.isLoading,
              onPressed: isBusy ? null : _handleRegister,
            ),
          ],
        ),
      ),
      extra: Text(
        'By creating an account you agree to the Terms and the Privacy '
        'Policy.',
        textAlign: TextAlign.center,
        style: AppTypography.rowMeta.copyWith(color: t.ink3),
      ),
      onGoogle: isBusy ? null : _handleGoogleSignIn,
      onApple: _showAppleButton ? (isBusy ? null : _handleAppleSignIn) : null,
      googleLoading: authState.isGoogleLoading,
      appleLoading: authState.isAppleLoading,
      footerPrompt: 'Already have one? ',
      footerAction: 'Sign in',
      onFooterTap: widget.onLoginTap,
    );
  }
}
