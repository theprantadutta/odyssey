import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../../../../common/theme/odyssey_tokens.dart';
import '../../../../common/widgets/odyssey/odyssey.dart';
import '../providers/auth_provider.dart';

/// The terms gate, shown once before the first sign-in.
class LegalAgreementScreen extends ConsumerStatefulWidget {
  const LegalAgreementScreen({super.key});

  @override
  ConsumerState<LegalAgreementScreen> createState() =>
      _LegalAgreementScreenState();
}

class _LegalAgreementScreenState extends ConsumerState<LegalAgreementScreen> {
  static const String _terms = 'Terms';
  static const String _privacy = 'Privacy';

  String _tab = _terms;
  bool _agreed = false;

  String _privacyContent = '';
  String _termsContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/legal/privacy.md'),
      rootBundle.loadString('assets/legal/terms.md'),
    ]);
    if (!mounted) return;
    setState(() {
      _privacyContent = results[0];
      _termsContent = results[1];
      _isLoading = false;
    });
  }

  Future<void> _continue() async {
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).setTermsAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.odyssey;
    final body = _tab == _terms ? _termsContent : _privacyContent;

    return OdysseyScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.authPadding,
              AppSizes.contentTop,
              AppSizes.authPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Before we\nbegin.',
                  style: AppTypography.screenTitle.copyWith(
                    fontSize: 38,
                    letterSpacing: -1.71,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                Text(
                  'The short version: your trips are yours, and we keep them '
                  'that way.',
                  style: AppTypography.subtitle.copyWith(color: t.ink2),
                ),
                const SizedBox(height: AppSizes.space20),
                SegmentedControl(
                  labels: const [_terms, _privacy],
                  selected: _tab,
                  onSelected: (value) {
                    HapticFeedback.selectionClick();
                    setState(() => _tab = value);
                  },
                ),
                const SizedBox(height: AppSizes.space16),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.authPadding,
                    ),
                    child: Column(
                      children: [
                        Skeleton(width: double.infinity, height: 14),
                        SizedBox(height: AppSizes.space10),
                        Skeleton(width: double.infinity, height: 14),
                        SizedBox(height: AppSizes.space10),
                        Skeleton(width: double.infinity, height: 14),
                      ],
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSizes.authPadding,
                    ),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(AppSizes.radiusTile),
                      border: Border.all(color: t.hairline),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSizes.space18),
                      child: Text(
                        // Rendered as plain text rather than Markdown. The
                        // documents are read once, at a gate, and a Markdown
                        // renderer here would pull its own type scale into a
                        // screen that has one.
                        body,
                        style: AppTypography.body.copyWith(color: t.ink2),
                      ),
                    ),
                  ),
          ),

          StickyFooter(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.authPadding,
              AppSizes.space16,
              AppSizes.authPadding,
              30,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Pressable(
                  onTap: () => setState(() => _agreed = !_agreed),
                  borderRadius: BorderRadius.circular(AppSizes.radiusRow),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.space8,
                    ),
                    child: Row(
                      children: [
                        CircleCheckbox(
                          checked: _agreed,
                          size: AppSizes.checkboxSmall,
                          onChanged: (value) => setState(() => _agreed = value),
                          semanticLabel: 'Agree to the terms',
                        ),
                        const SizedBox(width: AppSizes.space12),
                        Expanded(
                          child: Text(
                            'I have read and agree to the Terms and the '
                            'Privacy Policy.',
                            style: AppTypography.rowMeta.copyWith(
                              color: t.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.space12),
                PillButton(
                  label: _agreed ? 'Continue' : 'Agree to continue',
                  style: PillStyle.brand,
                  onPressed: _agreed ? _continue : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
