import 'package:flutter/material.dart';

import 'odyssey/inputs.dart';

/// The pre-2.0 text field API, re-pointed at [FieldCard] so the call sites
/// that still use it render in the new system.
///
/// New code should use [FieldCard] directly. The two differ in one way worth
/// knowing: this design has no floating label — the field's name sits above
/// the value as a mono eyebrow and stays there, so [label] is required in
/// practice even though the old API allowed it to be null.
@Deprecated('Use FieldCard')
class AppTextField extends StatelessWidget {
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

  final TextEditingController controller;
  final String? label;
  final String? hint;

  /// Ignored. A field card carries its name as an eyebrow rather than an icon.
  final IconData? prefixIcon;

  final Widget? suffix;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool enabled;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return FieldCard(
      label: label ?? hint ?? '',
      controller: controller,
      hint: hint,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      validator: validator,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      maxLines: maxLines,
      trailing: suffix,
    );
  }
}
