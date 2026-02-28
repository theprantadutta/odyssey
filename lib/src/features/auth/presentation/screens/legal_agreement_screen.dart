import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/animations/animation_constants.dart';
import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';
import '../providers/auth_provider.dart';

/// Legal agreement screen shown before authentication.
/// Users must accept the Privacy Policy and Terms & Conditions to proceed.
class LegalAgreementScreen extends ConsumerStatefulWidget {
  const LegalAgreementScreen({super.key});

  @override
  ConsumerState<LegalAgreementScreen> createState() =>
      _LegalAgreementScreenState();
}

class _LegalAgreementScreenState extends ConsumerState<LegalAgreementScreen>
    with SingleTickerProviderStateMixin {
  bool _agreed = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _privacyContent = '';
  String _termsContent = '';
  bool _isLoadingContent = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.slow,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppAnimations.slideUp,
    ));

    _loadContent();
    _animationController.forward();
  }

  Future<void> _loadContent() async {
    final results = await Future.wait([
      rootBundle.loadString('assets/legal/privacy.md'),
      rootBundle.loadString('assets/legal/terms.md'),
    ]);
    if (mounted) {
      setState(() {
        _privacyContent = results[0];
        _termsContent = results[1];
        _isLoadingContent = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    HapticFeedback.mediumImpact();
    await ref.read(authProvider.notifier).setTermsAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snowWhite,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const SizedBox(height: AppSizes.space24),

                  // Header icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.lemonLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sunnyYellow.withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 40,
                      color: AppColors.sunnyYellow,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),

                  // Title
                  Text(
                    'Legal Agreements',
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space8),

                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space24,
                    ),
                    child: Text(
                      'Please review our Privacy Policy and Terms & Conditions before continuing.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.slate,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSizes.space20),

                  // Tab bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.space24,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.warmGray,
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: AppColors.snowWhite,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusSm),
                          boxShadow: AppSizes.softShadow,
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: AppColors.charcoal,
                        unselectedLabelColor: AppColors.slate,
                        labelStyle: AppTypography.labelLarge,
                        unselectedLabelStyle: AppTypography.labelLarge,
                        padding: const EdgeInsets.all(4),
                        tabs: const [
                          Tab(text: 'Privacy Policy'),
                          Tab(text: 'Terms & Conditions'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.space16),

                  // Tab content
                  Expanded(
                    child: _isLoadingContent
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.sunnyYellow,
                            ),
                          )
                        : TabBarView(
                            children: [
                              _buildMarkdownTab(_privacyContent),
                              _buildMarkdownTab(_termsContent),
                            ],
                          ),
                  ),

                  // Bottom section: checkbox + button
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.space24,
                      AppSizes.space16,
                      AppSizes.space24,
                      MediaQuery.of(context).padding.bottom + AppSizes.space16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.snowWhite,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Checkbox
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _agreed = !_agreed);
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _agreed,
                                  onChanged: (value) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _agreed = value ?? false);
                                  },
                                  activeColor: AppColors.sunnyYellow,
                                  checkColor: AppColors.charcoal,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSizes.space12),
                              Expanded(
                                child: Text(
                                  'I agree to the Privacy Policy and Terms & Conditions',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.charcoal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.space16),

                        // Continue button
                        SizedBox(
                          width: double.infinity,
                          height: AppSizes.buttonHeightLg,
                          child: FilledButton(
                            onPressed: _agreed ? _onContinue : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.sunnyYellow,
                              foregroundColor: AppColors.charcoal,
                              disabledBackgroundColor:
                                  AppColors.warmGray,
                              disabledForegroundColor:
                                  AppColors.mutedGray,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppSizes.radiusMd),
                              ),
                            ),
                            child: Text('Continue', style: AppTypography.button),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownTab(String content) {
    return Markdown(
      data: content,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.space24,
        vertical: AppSizes.space8,
      ),
      styleSheet: MarkdownStyleSheet(
        h1: AppTypography.headlineLarge.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.bold,
        ),
        h2: AppTypography.headlineSmall.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
        h3: AppTypography.titleMedium.copyWith(
          color: AppColors.charcoal,
        ),
        p: AppTypography.bodyMedium.copyWith(
          color: AppColors.charcoal,
          height: 1.6,
        ),
        listBullet: AppTypography.bodyMedium.copyWith(
          color: AppColors.charcoal,
        ),
        strong: AppTypography.bodyMedium.copyWith(
          color: AppColors.charcoal,
          fontWeight: FontWeight.w600,
        ),
        em: AppTypography.bodyMedium.copyWith(
          color: AppColors.slate,
          fontStyle: FontStyle.italic,
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.warmGray,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
