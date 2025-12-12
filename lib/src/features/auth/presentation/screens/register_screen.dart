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

/// Playful register screen with vibrant design
/// Light background, white form card, yellow accents
class RegisterScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginTap;

  const RegisterScreen({
    super.key,
    this.onLoginTap,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    try {
      await ref.read(authProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: AppSizes.space12),
                Expanded(child: Text(e.toString())),
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
    }
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
                              'Create Account',
                              style: AppTypography.headlineMedium.copyWith(
                                color: AppColors.charcoal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSizes.space8),
                            Text(
                              'Start your adventure today!',
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
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  _confirmPasswordFocusNode.requestFocus(),
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
                            const SizedBox(height: AppSizes.space16),

                            // Confirm Password Field
                            _buildTextField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocusNode,
                              label: 'Confirm Password',
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              obscureText: _obscureConfirmPassword,
                              validator: (value) => Validators.confirmPassword(
                                value,
                                _passwordController.text,
                              ),
                              enabled: !authState.isLoading,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleRegister(),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.slate,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: AppSizes.space24),

                            // Register Button
                            AnimatedButton(
                              text: 'Create Account',
                              onPressed:
                                  authState.isLoading ? null : _handleRegister,
                              isLoading: authState.isLoading,
                              icon: Icons.rocket_launch_rounded,
                              height: AppSizes.buttonHeightLg,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space24),

                    // Login Link
                    Center(
                      child: GestureDetector(
                        onTap: authState.isLoading ? null : widget.onLoginTap,
                        child: RichText(
                          text: TextSpan(
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.slate,
                            ),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
                              TextSpan(
                                text: 'Sign In',
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
            Icons.explore,
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
}
