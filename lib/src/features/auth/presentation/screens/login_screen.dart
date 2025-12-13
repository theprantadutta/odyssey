import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/animations/animation_constants.dart';
import '../../../../common/animations/animated_widgets/animated_button.dart';
import '../../../../common/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Playful login screen with vibrant design
/// Light background, white form card, yellow accents
class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onRegisterTap;

  const LoginScreen({
    super.key,
    this.onRegisterTap,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppAnimations.bouncyEnter,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    try {
      await ref.read(authProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showErrorSnackBar(e.toString());
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final needsLinking = await ref.read(authProvider.notifier).signInWithGoogle();
      if (needsLinking && mounted) {
        _showAccountLinkingDialog();
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _showErrorSnackBar(e.toString());
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: AppSizes.space12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
      ),
    );
  }

  void _showAccountLinkingDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.snowWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sunnyYellow.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link, color: AppColors.sunnyYellow),
            ),
            const SizedBox(width: AppSizes.space12),
            Text(
              'Link Account',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.charcoal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An account with this email already exists. Enter your password to link your Google account.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: AppSizes.space16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                filled: true,
                fillColor: AppColors.warmGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).cancelAccountLinking();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.slate,
              ),
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final isLoading = ref.watch(authProvider).isLoading;
              return FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        try {
                          await ref.read(authProvider.notifier).linkGoogleAccount(
                                passwordController.text,
                              );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sunnyYellow,
                  foregroundColor: AppColors.charcoal,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Link Account'),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.cloudGray,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.space24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Section
                    _buildLogoSection(),
                    const SizedBox(height: AppSizes.space32),

                    // Form Card
                    Container(
                      padding: const EdgeInsets.all(AppSizes.space24),
                      decoration: BoxDecoration(
                        color: AppColors.snowWhite,
                        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
                        boxShadow: AppSizes.softShadow,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome Back!',
                              style: AppTypography.headlineMedium.copyWith(
                                color: AppColors.charcoal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSizes.space8),
                            Text(
                              'Sign in to continue your journey',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.slate,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSizes.space24),

                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              label: 'Email',
                              hint: 'your@email.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                              enabled: !authState.isLoading,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                            ),
                            const SizedBox(height: AppSizes.space16),

                            // Password Field
                            _buildTextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              label: 'Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              validator: Validators.password,
                              enabled: !authState.isLoading,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.slate,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: AppSizes.space24),

                            // Login Button
                            AnimatedButton(
                              text: 'Sign In',
                              onPressed: (authState.isLoading || authState.isGoogleLoading)
                                  ? null
                                  : _handleLogin,
                              isLoading: authState.isLoading,
                              icon: Icons.arrow_forward_rounded,
                              height: AppSizes.buttonHeightLg,
                            ),
                            const SizedBox(height: AppSizes.space16),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppColors.mutedGray,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.space16,
                                  ),
                                  child: Text(
                                    'or',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.slate,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: AppColors.mutedGray,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.space16),

                            // Google Sign-In Button
                            _buildGoogleSignInButton(authState),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space24),

                    // Register Link
                    Center(
                      child: GestureDetector(
                        onTap: authState.isLoading ? null : widget.onRegisterTap,
                        child: RichText(
                          text: TextSpan(
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.slate,
                            ),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: 'Sign Up',
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.sunnyYellow,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo with glow
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.lemonLight,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.sunnyYellow.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.travel_explore,
            size: 56,
            color: AppColors.sunnyYellow,
          ),
        ),
        const SizedBox(height: AppSizes.space16),
        Text(
          'Odyssey',
          style: AppTypography.brandLarge.copyWith(
            color: AppColors.charcoal,
            fontSize: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool enabled = true,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      onFieldSubmitted: onSubmitted,
      style: AppTypography.bodyLarge.copyWith(
        color: AppColors.charcoal,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.slate,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.mutedGray,
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.slate,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.warmGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.sunnyYellow,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGoogleSignInButton(AuthState authState) {
    final isLoading = authState.isGoogleLoading;
    final isDisabled = authState.isLoading || authState.isGoogleLoading;

    return SizedBox(
      height: AppSizes.buttonHeightLg,
      child: OutlinedButton(
        onPressed: isDisabled ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.charcoal,
          side: BorderSide(
            color: isDisabled ? AppColors.mutedGray : AppColors.slate.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.space16,
            vertical: AppSizes.space12,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.slate,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google logo (simplified)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: AppTypography.labelLarge.copyWith(
                          color: const Color(0xFF4285F4), // Google blue
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space12),
                  Text(
                    'Continue with Google',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
