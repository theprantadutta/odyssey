import 'package:flutter/material.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/brand_mark.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';

/// What this app is, who made it, and which build you are on.
Future<void> showAboutOdysseyDialog({
  required BuildContext context,
  required String appVersion,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AboutOdysseyDialog(appVersion: appVersion),
  );
}

class AboutOdysseyDialog extends StatelessWidget {
  const AboutOdysseyDialog({super.key, required this.appVersion});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    return Container(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: const OdysseyMark(size: 64)),
            const SizedBox(height: AppSizes.space20),

            Center(
              child: Text(
                'Odyssey',
                style: AppTypography.statSection.copyWith(color: t.ink),
              ),
            ),
            const SizedBox(height: AppSizes.space8),
            Center(
              child: Text(
                'Build $appVersion',
                style: AppTypography.monoDivider.copyWith(
                  fontSize: 9.5,
                  color: t.ink3,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space20),

            Text(
              'Plan the days, pack the bag, split the spend and keep the '
              'photos — Odyssey holds the whole journey.',
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: t.ink2),
            ),
            const SizedBox(height: AppSizes.space24),

            GroupedCard(
              children: [
                _MetaRow(label: 'Built by', value: 'Pranta Dutta'),
                _MetaRow(
                  label: 'Copyright',
                  value: '© ${DateTime.now().year}',
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space20),

            PillButton(
              label: 'Close',
              style: PillStyle.outline,
              onPressed: () => Navigator.of(context).pop(),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space16),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.rowLabel.copyWith(color: t.ink),
            ),
          ),
          Text(
            value,
            style: AppTypography.caption.copyWith(color: t.ink3),
          ),
        ],
      ),
    );
  }
}
