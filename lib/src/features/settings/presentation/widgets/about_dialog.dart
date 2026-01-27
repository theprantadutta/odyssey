import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/widgets/custom_button.dart';

/// Shows the About Odyssey dialog
Future<void> showAboutOdysseyDialog({
  required BuildContext context,
  required String appVersion,
}) {
  return showDialog(
    context: context,
    builder: (context) => AboutOdysseyDialog(appVersion: appVersion),
  );
}

class AboutOdysseyDialog extends StatelessWidget {
  final String appVersion;

  const AboutOdysseyDialog({
    super.key,
    required this.appVersion,
  });

  Future<void> _openDeveloperLink() async {
    final uri = Uri.parse('https://pranta.dev');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.skyBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.skyBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.space12),
                Text(
                  'About Odyssey',
                  style: AppTypography.headlineSmall.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.space24),

            // App Icon
            Container(
              padding: const EdgeInsets.all(AppSizes.space16),
              decoration: BoxDecoration(
                color: AppColors.lemonLight,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              child: const Icon(
                Icons.travel_explore,
                color: AppColors.goldenGlow,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSizes.space16),

            // Version
            Text(
              'Version $appVersion',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.space16),

            // Description
            Text(
              'Odyssey is your personal travel companion for planning and documenting your adventures.',
              style: AppTypography.bodyMedium.copyWith(
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),

            // Developer Section
            Text(
              'Developed & Maintained By',
              style: AppTypography.labelSmall.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: AppSizes.space8),

            // Developer Link
            Material(
              color: AppColors.oceanTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: InkWell(
                onTap: _openDeveloperLink,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.space16,
                    vertical: AppSizes.space12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pranta Dutta',
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.oceanTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: AppSizes.space8),
                      const Icon(
                        Icons.open_in_new_rounded,
                        color: AppColors.oceanTeal,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.space16),

            // Copyright
            Text(
              '© ${DateTime.now().year} Pranta Dutta.\nAll rights reserved.',
              style: AppTypography.caption.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.space24),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
