import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../common/theme/app_colors.dart';
import '../../../../common/theme/app_sizes.dart';
import '../../../../common/theme/app_typography.dart';

/// Full-screen viewer for legal documents (Privacy Policy, Terms & Conditions).
class LegalDocumentViewer extends StatefulWidget {
  final String title;
  final String assetPath;

  const LegalDocumentViewer({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LegalDocumentViewer> createState() => _LegalDocumentViewerState();
}

class _LegalDocumentViewerState extends State<LegalDocumentViewer> {
  String _content = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final content = await rootBundle.loadString(widget.assetPath);
    if (mounted) {
      setState(() {
        _content = content;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: AppTypography.headlineMedium.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.sunnyYellow),
            )
          : Markdown(
              data: _content,
              padding: const EdgeInsets.all(AppSizes.space16),
              styleSheet: MarkdownStyleSheet(
                h1: AppTypography.headlineLarge.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                h2: AppTypography.headlineSmall.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                h3: AppTypography.titleMedium.copyWith(
                  color: colorScheme.onSurface,
                ),
                p: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurface,
                  height: 1.6,
                ),
                listBullet: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurface,
                ),
                strong: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                em: AppTypography.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
