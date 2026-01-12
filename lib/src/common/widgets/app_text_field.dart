import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_typography.dart';

/// Standardized text field with consistent styling across the app
///
/// Provides:
/// - White background (snowWhite) for cleaner look
/// - Subtle border in unfocused state
/// - Yellow border with subtle glow on focus
/// - Consistent error styling
class AppTextField extends StatelessWidget {
  /// Controller for the text field
  final TextEditingController controller;

  /// Label text displayed above the field when focused
  final String? label;

  /// Hint text displayed when field is empty
  final String? hint;

  /// Prefix icon displayed at the start of the field
  final IconData? prefixIcon;

  /// Suffix widget displayed at the end of the field
  final Widget? suffix;

  /// Validation function
  final String? Function(String?)? validator;

  /// Number of lines for multiline input
  final int maxLines;

  /// Keyboard type for the input
  final TextInputType? keyboardType;

  /// Whether the field is enabled
  final bool enabled;

  /// Callback when the field is submitted
  final void Function(String)? onSubmitted;

  /// Callback when the field value changes
  final void Function(String)? onChanged;

  /// Whether to obscure text (for passwords)
  final bool obscureText;

  /// Text capitalization
  final TextCapitalization textCapitalization;

  /// Focus node for the field
  final FocusNode? focusNode;

  /// Whether to autofocus this field
  final bool autofocus;

  /// Text input action
  final TextInputAction? textInputAction;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.enabled = true,
    this.onSubmitted,
    this.onChanged,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      focusNode: focusNode,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      onChanged: onChanged,
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
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: AppColors.slate)
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.snowWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(
            color: AppColors.mutedGray.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(
            color: AppColors.mutedGray.withValues(alpha: 0.3),
            width: 1.5,
          ),
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
            width: 2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          borderSide: BorderSide(
            color: AppColors.mutedGray.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space12,
        ),
      ),
      validator: validator,
    );
  }
}

/// Text field variant with a labeled header above it
class LabeledTextField extends StatelessWidget {
  /// Label text displayed above the field
  final String label;

  /// Whether the field is required (shows asterisk)
  final bool isRequired;

  /// The text field widget
  final Widget child;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.child,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.charcoal,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSizes.space8),
        child,
      ],
    );
  }
}
