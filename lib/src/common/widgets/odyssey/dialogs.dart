import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_sizes.dart';
import '../../theme/app_typography.dart';
import '../../theme/odyssey_tokens.dart';
import 'buttons.dart';
import 'chips.dart';
import 'inputs.dart';
import 'pressable.dart';
import 'surfaces.dart';

/// A confirmation sheet in the Odyssey surface language.
///
/// This palette has no red, so a destructive action is not signalled by
/// colour — it is signalled by copy, and by [typeToConfirm] when the action is
/// severe enough to deserve friction. The confirm button wears the ordinary
/// action colour either way.
///
/// Returns true only if the user confirmed.
Future<bool> showOdysseyConfirm({
  required BuildContext context,
  required String title,
  required List<String> body,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',

  /// When set, the confirm button stays inert until the user types this word.
  String? typeToConfirm,
}) async {
  HapticFeedback.lightImpact();

  final result = await showModalBottomSheet<bool>(
    // Pushed on the root navigator so the sheet covers the tab bar. The
    // bar belongs to the shell's Scaffold, which sits outside a branch
    // navigator - present it there and the bar paints over the sheet,
    // undimmed, with a dead strip of screen beneath it.
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ConfirmSheet(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      typeToConfirm: typeToConfirm,
    ),
  );
  return result ?? false;
}

class _ConfirmSheet extends StatefulWidget {
  const _ConfirmSheet({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    this.typeToConfirm,
  });

  final String title;
  final List<String> body;
  final String confirmLabel;
  final String cancelLabel;
  final String? typeToConfirm;

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    final word = widget.typeToConfirm;
    if (word == null) return true;
    return _controller.text.trim().toUpperCase() == word.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.space24,
        AppSizes.screenPadding,
        AppSizes.space24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(t.sheet, t.canvas),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSizes.radiusSheet),
        ),
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: AppTypography.statSmall.copyWith(color: t.ink),
            ),
            const SizedBox(height: AppSizes.space14),
            for (final paragraph in widget.body) ...[
              Text(
                paragraph,
                style: AppTypography.subtitle.copyWith(color: t.ink2),
              ),
              const SizedBox(height: AppSizes.space12),
            ],
            if (widget.typeToConfirm != null) ...[
              const SizedBox(height: AppSizes.space4),
              FieldCard(
                label: 'Type ${widget.typeToConfirm} to confirm',
                controller: _controller,
                hint: widget.typeToConfirm,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.space18),
            ] else
              const SizedBox(height: AppSizes.space6),
            PillButton(
              label: widget.confirmLabel,
              onPressed: _canConfirm
                  ? () => Navigator.of(context).pop(true)
                  : null,
            ),
            const SizedBox(height: AppSizes.space10),
            PillButton(
              label: widget.cancelLabel,
              style: PillStyle.outline,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single-choice picker sheet — home currency, units, anything that is a
/// short list of options rather than a screen of its own.
Future<T?> showOdysseyPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  bool asRows = false,
}) {
  return showModalBottomSheet<T>(
    // Pushed on the root navigator so the sheet covers the tab bar. The
    // bar belongs to the shell's Scaffold, which sits outside a branch
    // navigator - present it there and the bar paints over the sheet,
    // undimmed, with a dead strip of screen beneath it.
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final t = context.odyssey;
      return Container(
        // A sheet spans the screen. Without this it shrinks to its content -
        // the Column below is MainAxisSize.min and a Wrap sizes to its widest
        // run - and a sheet of three short options came up as a narrow panel
        // floating inset from both edges.
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          AppSizes.space24,
          AppSizes.screenPadding,
          AppSizes.space24,
        ),
        decoration: BoxDecoration(
          color: Color.alphaBlend(t.sheet, t.canvas),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusSheet),
          ),
          border: Border(top: BorderSide(color: t.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EyebrowLabel(title),
              const SizedBox(height: AppSizes.space16),
              Flexible(
                child: SingleChildScrollView(
                  // Chips suit a set of values to choose between - a year, a
                  // currency. A short list of *actions* reads better as rows:
                  // each one full width, with room to tap.
                  child: asRows
                      ? GroupedCard(
                          children: [
                            for (final option in options)
                              _PickerRow(
                                label: labelOf(option),
                                selected: option == selected,
                                onTap: () =>
                                    Navigator.of(context).pop(option),
                              ),
                          ],
                        )
                      : Wrap(
                          spacing: AppSizes.space8,
                          runSpacing: AppSizes.space8,
                          children: [
                            for (final option in options)
                              OdysseyChip(
                                label: labelOf(option),
                                selected: option == selected,
                                activeStyle: ChipActiveStyle.action,
                                onTap: () =>
                                    Navigator.of(context).pop(option),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The system's only message affordance. There is no error colour, so both
/// success and failure arrive on the same inverted surface and differ in what
/// they say.
void showOdysseyMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// One option in a row-style [showOdysseyPicker].
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Pressable(
      onTap: onTap,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.space16,
          vertical: AppSizes.space16,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.rowTitle.copyWith(color: t.ink),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                size: AppSizes.iconMd,
                color: t.limeText,
              ),
          ],
        ),
      ),
    );
  }
}
