import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/custom_button.dart';
import '../../../../common/utils/validators.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onRegisterTap;

  const LoginScreen({
    super.key,
    this.onRegisterTap,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(authProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        // Navigation will be handled by GoRouter auth redirect
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.space24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Title
                    Icon(
                      Icons.travel_explore,
                      size: 80,
                      color: AppColors.sunsetGold,
                    ),
                    const SizedBox(height: AppSizes.space16),

                    Text(
                      'Odyssey',
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.textOnDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.space8),

                    Text(
                      'Your Journey Begins',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.softGold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.space48),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textOnDark,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.softGold,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.softGold,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: BorderSide(
                            color: AppColors.softGold.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: BorderSide(
                            color: AppColors.softGold.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: const BorderSide(
                            color: AppColors.sunsetGold,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: const BorderSide(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      validator: Validators.email,
                      enabled: !authState.isLoading,
                    ),
                    const SizedBox(height: AppSizes.space16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textOnDark,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.softGold,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.softGold,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.softGold,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: BorderSide(
                            color: AppColors.softGold.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: BorderSide(
                            color: AppColors.softGold.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: const BorderSide(
                            color: AppColors.sunsetGold,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          borderSide: const BorderSide(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      validator: Validators.password,
                      enabled: !authState.isLoading,
                    ),
                    const SizedBox(height: AppSizes.space32),

                    // Login Button
                    CustomButton(
                      text: 'Login',
                      onPressed: authState.isLoading ? null : _handleLogin,
                      isLoading: authState.isLoading,
                    ),
                    const SizedBox(height: AppSizes.space16),

                    // Register Link
                    TextButton(
                      onPressed: authState.isLoading ? null : widget.onRegisterTap,
                      child: Text(
                        'Don\'t have an account? Register',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.softGold,
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
}
