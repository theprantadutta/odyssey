import 'package:flutter/material.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'buttons.dart';
import 'scaffold.dart';

/// The shell every "add or edit one thing" screen uses — an activity, an
/// expense, a packing item, a document, a photo.
///
/// The design does not draw these, so they are built from the pattern screen
/// 3d establishes: a header with a close glyph, the title set large, the
/// fields, and a sticky footer whose label says what will happen.
///
/// The footer fades the canvas up behind it, so content dissolves rather than
/// being cut off at the button.
class OdysseyFormScreen extends StatelessWidget {
  const OdysseyFormScreen({
    super.key,
    required this.title,
    required this.children,
    required this.submitLabel,
    this.onSubmit,
    this.caption,
    this.subtitle,
    this.isLoading = false,
    this.formKey,
    this.onChanged,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Set at screen-title size — "New plan", "Edit expense".
  final String title;

  /// The small centred caption in the header row.
  final String? caption;

  /// A line under the title.
  final String? subtitle;

  final List<Widget> children;

  /// The footer button's label. Say what will happen, not "Submit".
  final String submitLabel;

  /// Null disables the button, which is how the form reports it is incomplete.
  final VoidCallback? onSubmit;

  final bool isLoading;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onChanged;

  /// An optional second action beneath the primary one — usually delete.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return OdysseyScaffold(
      body: Form(
        key: formKey,
        onChanged: onChanged,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenPadding,
                  AppSizes.contentTop,
                  AppSizes.screenPadding,
                  AppSizes.scrollBottom,
                ),
                children: [
                  ScreenHeader(
                    title: caption,
                    leadingGlyph: '✕',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: AppSizes.space20),
                  Text(
                    title,
                    style: AppTypography.screenTitle.copyWith(
                      height: 1.02,
                      color: t.ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSizes.space10),
                    Text(
                      subtitle!,
                      style: AppTypography.meta.copyWith(color: t.ink3),
                    ),
                  ],
                  const SizedBox(height: AppSizes.space20),
                  ...children,
                ],
              ),
            ),
            StickyFooter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PillButton(
                    label: submitLabel,
                    isLoading: isLoading,
                    onPressed: onSubmit,
                  ),
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: AppSizes.space10),
                    PillButton(
                      label: secondaryLabel!,
                      style: PillStyle.outline,
                      onPressed: onSecondary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.space14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled group inside a form: a mono eyebrow with its content beneath.
class FormGroup extends StatelessWidget {
  const FormGroup({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.eyebrow.copyWith(color: t.ink3),
        ),
        const SizedBox(height: AppSizes.space12),
        child,
      ],
    );
  }
}
