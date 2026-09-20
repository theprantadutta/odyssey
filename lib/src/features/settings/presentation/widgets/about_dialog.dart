import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';

/// What this app is, who made it, and which build you are on.
Future<void> showAboutOdysseyDialog({
  required BuildContext context,
  required String appVersion,
}) {
  return showModalBottomSheet<void>(
    // Pushed on the root navigator so the sheet covers the tab bar. The
    // bar belongs to the shell's Scaffold, which sits outside a branch
    // navigator - present it there and the bar paints over the sheet,
    // undimmed, with a dead strip of screen beneath it.
    useRootNavigator: true,
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
                  label: 'Website',
                  value: 'pranta.dev',
                  url: Uri.parse('https://pranta.dev'),
                ),
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
  const _MetaRow({required this.label, required this.value, this.url});

  final String label;
  final String value;

  /// Opens in the browser when given. The row then reads as a link - the value
  /// in the accent's text weight, with an outward arrow - rather than sitting
  /// there looking like the two facts above it.
  final Uri? url;

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;

    final row = Padding(
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
            style: AppTypography.caption.copyWith(
              color: url == null ? t.ink3 : t.limeText,
            ),
          ),
          if (url != null) ...[
            const SizedBox(width: AppSizes.space6),
            Icon(
              Icons.north_east_rounded,
              size: AppSizes.iconXs,
              color: t.limeText,
            ),
          ],
        ],
      ),
    );

    if (url == null) return row;

    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        // Externally, so the site opens in the browser the user already has
        // signed in rather than in a stripped-down view inside the app.
        launchUrl(url!, mode: LaunchMode.externalApplication);
      },
      semanticLabel: '$label, $value, opens in your browser',
      child: row,
    );
  }
}
