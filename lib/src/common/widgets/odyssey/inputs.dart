import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'pressable.dart';

/// The input field of this design system: a card box with a mono eyebrow
/// label above the value.
///
/// Focus is signalled by swapping the hairline for a 1px lime border — that is
/// the focus state for *every* input in the system, in both themes.
///
/// ```dart
/// FieldCard(
///   label: 'Email',
///   controller: _email,
///   hint: 'you@example.com',
///   keyboardType: TextInputType.emailAddress,
/// )
/// ```
class FieldCard extends StatefulWidget {
  const FieldCard({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.trailing,
    this.readOnly = false,
    this.onTap,
    this.autofillHints,
  });

  /// Shown as the mono eyebrow. Uppercased for you.
  final String label;

  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final int maxLines;
  final int? minLines;

  /// Bottom-aligned affordance inside the box — the password field's "Show".
  final Widget? trailing;

  /// Makes the box a tappable display rather than an editable field, for
  /// values chosen elsewhere (a date, a location, a currency).
  final bool readOnly;

  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;

  @override
  State<FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<FieldCard> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsNode = false;
  bool _focused = false;
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _ownsNode = widget.focusNode == null;
    _obscured = widget.obscureText;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return FormField<String>(
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller?.text),
      builder: (field) {
        // No red exists in this palette, so a failed field says what is wrong
        // in copy beneath the box and keeps its border on-system.
        final hasError = field.hasError;
        final borderColor = _focused
            ? AppColors.accent
            : (hasError ? t.ink2 : t.hairline);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: AppSizes.durationState,
              curve: AppSizes.curveState,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.space18,
                vertical: AppSizes.space16,
              ),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(AppSizes.radiusInput),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label.toUpperCase(),
                          style: AppTypography.eyebrow.copyWith(color: t.ink3),
                        ),
                        const SizedBox(height: 7),
                        _buildInput(context, t, field),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: AppSizes.space12),
                    widget.trailing!,
                  ] else if (widget.obscureText) ...[
                    const SizedBox(width: AppSizes.space12),
                    Pressable(
                      onTap: () => setState(() => _obscured = !_obscured),
                      borderRadius: BorderRadius.circular(AppSizes.radiusChipXs),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _obscured ? 'Show' : 'Hide',
                          style: AppTypography.legend.copyWith(color: t.ink2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSizes.space18,
                  top: AppSizes.space6,
                ),
                child: Text(
                  field.errorText!,
                  style: AppTypography.rowMeta.copyWith(color: t.ink2),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildInput(
    BuildContext context,
    OdysseyTokens t,
    FormFieldState<String> field,
  ) {
    if (widget.readOnly) {
      final value = widget.controller?.text ?? '';
      return Pressable(
        onTap: widget.onTap,
        tint: false,
        child: Text(
          value.isEmpty ? (widget.hint ?? '—') : value,
          style: AppTypography.fieldValue.copyWith(
            color: value.isEmpty ? t.ink3 : t.ink,
          ),
        ),
      );
    }

    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      autofillHints: widget.autofillHints,
      cursorColor: AppColors.accent,
      cursorWidth: 1.5,
      style: AppTypography.fieldValue.copyWith(
        color: t.ink,
        // The mocks render a password as ●●●●●●●● at 0.2em tracking.
        letterSpacing: widget.obscureText && _obscured ? 3 : null,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: widget.hint,
        hintStyle: AppTypography.fieldValue.copyWith(
          color: t.ink3,
          // Reset explicitly: the decorator merges the field's own style under
          // this one, so the 0.2em tracking meant for ●●●●●●●● would otherwise
          // stretch the placeholder out as well.
          letterSpacing: AppTypography.fieldValue.letterSpacing ?? 0,
        ),
        filled: false,
      ),
      onChanged: (value) {
        field.didChange(value);
        widget.onChanged?.call(value);
      },
      onSubmitted: widget.onSubmitted,
    );
  }
}

/// A read-only summary box — the From / To pair under the trip calendar.
///
/// Mono eyebrow, then the value in Manrope 15/700, or an em dash when unset.
class ValueCard extends StatelessWidget {
  const ValueCard({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final hasValue = value != null && value!.isNotEmpty;

    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusRow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusRow),
          border: Border.all(color: t.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(color: t.ink3),
            ),
            const SizedBox(height: 7),
            Text(
              hasValue ? value! : '—',
              style: AppTypography.fieldValueStrong.copyWith(
                color: hasValue ? t.ink : t.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 46×28 switch from the settings screen.
///
/// Off: a neutral track with a pale knob. On: the track takes the primary
/// action colour and the knob takes the *glyph* colour — obsidian on lime in
/// dark, lime on obsidian in light.
class OdysseySwitch extends StatelessWidget {
  const OdysseySwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final enabled = onChanged != null;

    final trackColor = value
        ? t.action
        : (t.isDark ? AppColors.darkCardAlt : AppColors.lightDashed);
    final knobColor = value
        ? (t.isDark ? AppColors.obsidian : AppColors.accent)
        : (t.isDark ? AppColors.darkInk2 : Colors.white);

    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: AppSizes.durationKnob,
            curve: AppSizes.curveKnob,
            width: AppSizes.switchSize.width,
            height: AppSizes.switchSize.height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            ),
            child: AnimatedAlign(
              duration: AppSizes.durationKnob,
              curve: AppSizes.curveKnob,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: AppSizes.switchKnob,
                height: AppSizes.switchKnob,
                decoration: BoxDecoration(
                  color: knobColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The circular checkbox on activity cards and packing rows.
///
/// Idle is a 1.6px ring; checked fills with the action colour and shows a `✓`.
class CircleCheckbox extends StatelessWidget {
  const CircleCheckbox({
    super.key,
    required this.checked,
    this.onChanged,
    this.size = AppSizes.checkboxLarge,
    this.semanticLabel,
  });

  final bool checked;
  final ValueChanged<bool>? onChanged;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Semantics(
      checked: checked,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!checked),
        child: AnimatedContainer(
          duration: AppSizes.durationState,
          curve: AppSizes.curveState,
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: checked ? t.action : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: checked ? t.action : t.ink3,
              width: AppSizes.checkboxBorder,
            ),
          ),
          child: checked
              ? Text(
                  '✓',
                  style: AppTypography.glyph.copyWith(
                    fontSize: size * 0.5,
                    color: t.onAction,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// A search bar: a fully rounded card with a trailing action circle.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 7, 7, 7),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        border: Border.all(color: t.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: readOnly
                ? Pressable(
                    onTap: onTap,
                    tint: false,
                    child: Text(
                      hint,
                      style: AppTypography.placeholder.copyWith(color: t.ink3),
                    ),
                  )
                : TextField(
                    controller: controller,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    cursorColor: AppColors.accent,
                    cursorWidth: 1.5,
                    style: AppTypography.placeholder.copyWith(color: t.ink),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: hint,
                      hintStyle:
                          AppTypography.placeholder.copyWith(color: t.ink3),
                      filled: false,
                    ),
                  ),
          ),
          const SizedBox(width: AppSizes.space10),
          Container(
            width: AppSizes.circleSearch,
            height: AppSizes.circleSearch,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.action, shape: BoxShape.circle),
            child: Icon(
              Icons.search,
              size: AppSizes.iconMd,
              color: t.actionGlyph,
            ),
          ),
        ],
      ),
    );
  }
}
